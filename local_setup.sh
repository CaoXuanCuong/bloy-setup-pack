#!/bin/bash -i

#COLORS
# Reset
Color_Off=$(tput sgr0) # Text Reset
Red=$(tput setaf 1)    # Red
Green=$(tput setaf 2)  # Green
Yellow=$(tput setaf 3) # Yellow
Purple=$(tput setaf 5) # Purple
Cyan=$(tput setaf 6)   # Cyan

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
option="${1}"
source script.env

# check if systemd is enabled
function check_systemd_enabled() {
  if [[ $(systemctl is-system-running) == "offline" ]]; then
    echo "${Red}********Systemd is not enabled********${Color_Off}"
    tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF
    echo "${Red}********Please restart wsl by opening window powershell and run command: wsl.exe --shutdown********${Color_Off}"
    exit 1
  fi
}

# install required packages
function install_dependencies() {
  echo "${Green}********Installing required packages********${Color_Off}"
  apt update
  apt install -y curl wget mysql-server redis openssh-server

  echo "${Green}********Configuring mysqldb********${Color_Off}"
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';CREATE USER 'root'@'%' IDENTIFIED BY '$DB_ROOT_PASSWORD';GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;FLUSH PRIVILEGES;"
  
  sleep 5
  
  echo "${Green}********Configuring mysql bind address********${Color_Off}"
  sed -i -E 's,bind-address.*$,bind-address = 0.0.0.0,g' /etc/mysql/mysql.conf.d/mysqld.cnf
  echo "Restarting mysql service..."
  systemctl restart mysql

  if ! command -v cloudflared &>/dev/null; then
    # install cloudflare cli
    echo "${Green}********Installing cloudflare cli********${Color_Off}"
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && dpkg -i cloudflared-linux-amd64.deb && rm -f cloudflared-linux-amd64.deb
  fi
}

function install_nvm_and_node() {
  # run at current user using sudo_user
  sudo -i -u $SUDO_USER bash <<EOF
  if [[ -f "~/.nvm/nvm.sh" ]]; then
    echo "nvm is already installed"
    return
  fi

  echo "${Green}********Install nvm and node 16.20.1********${Color_Off}"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  source ~/.bashrc
  source ~/.nvm/nvm.sh
  nvm install 16.20.1
  nvm alias default 16.20.1
  nvm use default
  npm install pm2 nodemon -g
  sudo env PATH=\$PATH:~/.nvm/versions/node/v16.20.1/bin ~/.nvm/versions/node/v16.20.1/lib/node_modules/pm2/bin/pm2 startup systemd -u $SUDO_USER --hp ~
EOF
}

function setup_tailscale() {
  echo "${Red}********WARNING: for workplace devices only********${Color_Off}"
  echo "${Red}********do not install on your personal devices********${Color_Off}"
  echo "${Red}********setup_tailscale will give root access to your WSL machine********${Color_Off}"
  read -p "Continue? (y/n): choose y if this is a workplace device " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi

  echo "${Green}********Installing tailscale********${Color_Off}"
  # check if tailscale is installed
  if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  tailscale up --login-server=$TAILSCALE_HOST --authkey=$TAILSCALE_AUTHKEY --reset
}

function config_os() {
  # config sudo nopasswd
  echo "${Green}********Config sudo nopasswd********${Color_Off}"
  sed -i -E 's,^%sudo.*$,%sudo ALL=(ALL:ALL) NOPASSWD:ALL,g' /etc/sudoers

  echo "${Green}********Change hostname to $USERNAME********${Color_Off}"
  hostnamectl set-hostname $USERNAME
  sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$USERNAME/g" /etc/hosts
}

function config_ssh() {
  sed -i -E 's,^#?Port.*$,Port 8022,' /etc/ssh/sshd_config
  sed -i -E 's,^#?PasswordAuthentication.*$,PasswordAuthentication yes,' /etc/ssh/sshd_config
  sed -i -E 's,^#?PermitEmptyPasswords.*$,PermitEmptyPasswords yes,' /etc/ssh/sshd_config
  useradd -m -s /bin/bash ssh
  echo "ssh:ssh" | chpasswd
  usermod -aG sudo ssh
  systemctl restart sshd
}

function setup_shell() {
  echo "${Green}********Configuring shell********${Color_Off}"
  if [[ -f "/root/.zshrc" ]]; then
    echo "zsh is already installed"
    return
  fi

  sudo sed s/required/sufficient/g -i /etc/pam.d/chsh
  # clean files
  rm -rf /usr/share/oh-my-zsh/zshrc /usr/share/oh-my-zsh /usr/share/p10k.zsh /usr/share/.dir_colors

  # install zsh and oh-my-zsh
  echo "${Green}********Installing zsh and oh-my-zsh********${Color_Off}"
  apt install -y zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  # install plugins
  echo "${Green}********Installing zsh plugins********${Color_Off}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

  sed -i -E 's,^plugins=\(.*$,plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search z nvm),g' ~/.zshrc

  # install powerlevel10k theme
  echo "${Green}********Installing powerlevel10k theme********${Color_Off}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
  sed -i -E 's,^ZSH_THEME=.*$,ZSH_THEME="powerlevel10k/powerlevel10k",g' ~/.zshrc
  sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/g' ~/.zshrc
  curl -o ~/.p10k.zsh https://raw.githubusercontent.com/romkatv/powerlevel10k/master/config/p10k-pure.zsh
  sudo chsh -s $(which zsh) $(whoami)
  mv /root/.oh-my-zsh /usr/share/
  mv /usr/share/.oh-my-zsh /usr/share/oh-my-zsh
  mv /root/.p10k.zsh /usr/share/p10k.zsh

  sed -i 's|export ZSH=.*|export ZSH="\/usr\/share\/oh-my-zsh"|g' /root/.zshrc
  cp /root/.zshrc /usr/share/oh-my-zsh/zshrc

  ln -f /usr/share/oh-my-zsh/zshrc /etc/skel/.zshrc
  
  # install nord dircolors
  mkdir -p /usr/share/.dir_colors
  git clone --depth=1 https://github.com/arcticicestudio/nord-dircolors.git /usr/share/.dir_colors
  tee -a /usr/share/oh-my-zsh/zshrc >/dev/null <<'EOF'
test -r "/usr/share/.dir_colors" && eval $(dircolors /usr/share/.dir_colors)
EOF

  for dir in /home/*; do
    user=$(basename "$dir")
    sudo -i -u $user bash <<EOF
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
echo $user | chsh -s /usr/bin/zsh
EOF
  done
}

function setup_cloudflare_tunnel() {
  bash $SCRIPTDIR/setup_cloudfare_tunnel.sh
}

function init() {
  check_systemd_enabled
  config_os
  setup_shell

  # redirect output to log file
  exec &> >(tee -a "$LOG_FILE")

  install_dependencies
  config_ssh
  install_nvm_and_node

  setup_cloudflare_tunnel

  echo "${Green}INFO: Install dev environment successfully${Color_Off}"
  echo "${Green}INFO: Run \"zsh\" command to load environment and configure your new shell${Color_Off}"
}

case ${option} in
init)
  init
  ;;
setup_tailscale)
  setup_tailscale
  ;;
setup_shell)
  setup_shell
  ;;
config_os)
  config_os
  ;;
install_dependencies)
  install_dependencies
  ;;
install_nvm_and_node)
  install_nvm_and_node
  ;;
config_ssh)
  config_ssh
  ;;
setup_cloudfare_tunnel)
  setup_cloudflare_tunnel
  ;;
*)
  echo "Usage: ./local_setup <option>"
  echo "Options:"
  echo "  init    : install dependencies, nvm, node, pm2, cloudflare tunnel"
  echo "  setup_tailscale : setup tailscale (for workplace devices only, install in case you need assistance from devops team)"
  echo "  setup_shell : setup zsh shell"
  echo "  setup_cloudfare_tunnel : setup cloudflare tunnel"
  echo "  config_os : config os"
  echo "  install_dependencies : install dependencies"
  echo "  install_nvm_and_node : install nvm and node"
  echo "  config_ssh : config ssh"
  ;;
esac
