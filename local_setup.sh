#!/bin/bash -i

#COLORS
# Reset
Color_Off=$(tput sgr0) # Text Reset
Red=$(tput setaf 1)    # Red
Green=$(tput setaf 2)  # Green
Yellow=$(tput setaf 3) # Yellow
Purple=$(tput setaf 5) # Purple
Cyan=$(tput setaf 6)   # Cyan

if [[ $EUID -ne 0 ]]; then
  echo "${Red}******** Permission denied, please run with sudo ********${Color_Off}"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -L "$0" ]; then
  script=$(readlink -f "$0")
  script_dir=$(dirname "$script")
fi
cd $script_dir

option="${1}"
shift 1
FORCE_INSTALL=false

while getopts ":f" opt; do
  case $opt in
  f)
    FORCE_INSTALL=true
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    ;;
  esac
done

if [ ! -f "script.env" ]; then
  echo "${Green}******** Create script.env file ********${Color_Off}"

  echo -n "${Cyan} Enter your USERNAME (Ex: tuannm): ${Color_Off}"
  read -r USERNAME
  echo -n "${Cyan} Enter your unique DEV SITE ID (string & number) (e.g. tuannm123): ${Color_Off}"
  read -r DEV_SITE

  cp script.env.example script.env

  sed -i "s/<DEV_SITE_ID>/$DEV_SITE/g" script.env
  sed -i "s/<USERNAME>/$USERNAME/g" script.env
fi

source script.env

if [[ "$DEV_SITE" == "<DEV_SITE_ID>" || "$USERNAME" == "<USERNAME>" ]]; then
  rm -f script.env
  echo "${Red} ******** Please update environment variable ********${Color_Off}"
  exit 1
fi

if [[ -z "$DEV_SITE" ]] || ! [[ "$DEV_SITE" =~ ^[a-zA-Z0-9-]+$ ]]; then
  rm -f script.env
  echo "ERROR: DEV_SITE is empty or contains non-alphanumeric characters"
  echo "${Red} ******** Please update environment variable ********${Color_Off}"
  exit 1
fi

if [[ -z "$USERNAME" ]] || ! [[ "$USERNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  rm -f script.env
  echo "ERROR: USERNAME is empty or contains non-alphanumeric characters"
  echo "${Red} ******** Please update environment variable ********${Color_Off}"
  exit 1
fi

export DEV_SITE=$DEV_SITE
export CF_ZONE_NAME=$CF_ZONE_NAME

IS_WSL=$(uname -a | grep -i microsoft)

# check if systemd is enabled
function check_systemd_enabled() {
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}******** Skipping check systemd ********${Color_Off}"
    return;
  fi
  if [[ $(systemctl is-system-running) == "offline" ]]; then
    echo "${Red}******** Systemd is not enabled ********${Color_Off}"
    tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF
    echo "${Red}********Please restart wsl by opening window powershell and run command: wsl.exe --shutdown********${Color_Off}"
    exit 1
  fi
}

if ! command -v nala &>/dev/null; then
  echo "Installing nala package manager..."
  sudo apt update
  sudo apt install nala -y
fi

# install required packages
function install_dependencies() {
  packages=(
    git
    curl
    wget
    openssh-server
  )

  tools=(
    mysql
    redis
  )

  echo "${Green}******** Installing required packages ********${Color_Off}"
  nala update
  nala install -y ${packages[@]}

  if [[ $IS_WSL == "" ]]; then
    echo "${Red}******** Do you want to install dependencies (mysql, redis) using docker? (y/n) ********${Color_Off}"
    read -r answer
    if [[ $answer == "n" ]]; then
      echo "${Red}******** Skipping install dependencies ********${Color_Off}"
      return;
    fi
  fi

  if ! docker info &>/dev/null; then
    echo "${Green} ******** Installing docker...********${Color_Off}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh
  fi

  sudo apt-get update
  sudo apt-get install docker-compose-plugin

  sudo groupadd docker
  sudo usermod -aG docker $SUDO_USER
  newgrp docker

  for tool in "${tools[@]}"; do
    if [[ $FORCE_INSTALL == false ]] && [[ $(docker ps -q -f name=$tool) == "" ]]; then
      echo "${Green} ******** Installing $tool container...********${Color_Off}"
      cp tools/$tool/.env.example tools/$tool/.env
      docker compose -f tools/$tool/docker-compose.yml up -d
    fi
  done
}

function install_node() {
  # run at current user using sudo_user
  sudo -i -u $SUDO_USER bash <<EOF
  if [[ $FORCE_INSTALL == false ]] && [[ -f "~/.nvm/nvm.sh" ]]; then
    echo "nvm is already installed"
    return
  fi

  echo "${Green}********Install nvm and node 16.20.1********${Color_Off}"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

  if ! grep -q "export NVM_DIR" ~/.zshrc; then
   bash -c "cat >> ~/.zshrc" <<'INNER_EOF'
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
INNER_EOF
  fi

  if ! grep -q "export NVM_DIR" ~/.bashrc; then
   bash -c "cat >> ~/.bashrc" <<'INNER_EOF'
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
INNER_EOF
  fi

  source ~/.nvm/nvm.sh
  nvm install 16.20.1
  nvm alias default 16.20.1
  nvm use default
  corepack enable
  npm install pm2 nodemon -g
  pm2 startup
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
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}******** Skipping config os ********${Color_Off}"
    return;
  fi
  # config sudo nopasswd
  echo "${Green}********Config sudo nopasswd********${Color_Off}"
  sed -i -E 's,^%sudo.*$,%sudo ALL=(ALL:ALL) NOPASSWD:ALL,g' /etc/sudoers

  echo "${Green}********Change hostname to $USERNAME********${Color_Off}"
  hostnamectl set-hostname $USERNAME
  sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$USERNAME/g" /etc/hosts
}

function config_ssh() {
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}******** Skipping config ssh ********${Color_Off}"
    return;
  fi

  sed -i -E 's,^#?Port.*$,Port 8022,' /etc/ssh/sshd_config
  sed -i -E 's,^#?PasswordAuthentication.*$,PasswordAuthentication yes,' /etc/ssh/sshd_config
  sed -i -E 's,^#?PermitEmptyPasswords.*$,PermitEmptyPasswords yes,' /etc/ssh/sshd_config
  useradd -m -s /bin/bash ssh
  echo "ssh:ssh" | chpasswd
  usermod -aG sudo ssh
  systemctl restart sshd
}

function setup_shell() {
  if [[ $FORCE_INSTALL == false ]] && [[ -f "/root/.zshrc" ]]; then
    echo "zsh is already installed. skipping"
    return
  fi

  echo "${Green}********Configuring shell********${Color_Off}"

  sudo sed s/required/sufficient/g -i /etc/pam.d/chsh
  # clean files
  rm -rf /usr/share/oh-my-zsh/zshrc /usr/share/oh-my-zsh /usr/share/p10k.zsh /usr/share/.dir_colors

  # install zsh and oh-my-zsh
  echo "${Green}********Installing zsh and oh-my-zsh********${Color_Off}"
  nala install -y zsh
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
  mkdir -p /usr/local/bin
  tee -a /usr/share/oh-my-zsh/zshrc >/dev/null <<EOF
export PATH="\$PATH:/usr/local/bin:\$HOME/.local/bin:\$HOME/bin"
export PATH=\$(printf %s "\$PATH" | awk -vRS=: '!a[\$0]++' | paste -s -d:)
export DEV_SITE=$DEV_SITE
export CF_ZONE_NAME=$CF_ZONE_NAME
EOF

  ln -sf $script_dir/local_setup.sh /usr/local/bin/local_setup
  chmod +x /usr/local/bin/local_setup

  for dir in /home/*; do
    user=$(basename "$dir")
    sudo -i -u $user bash <<EOF
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
echo $user | chsh -s /usr/bin/zsh
grep -q 'export DEV_SITE' ~/.bashrc || echo "export DEV_SITE=$DEV_SITE" >> ~/.bashrc
grep -q 'export CF_ZONE_NAME' ~/.bashrc || echo "export CF_ZONE_NAME=$CF_ZONE_NAME" >> ~/.bashrc
EOF
  done
}

function setup_cloudflare_tunnel() {
  bash $script_dir/setup_cloudflare_tunnel.sh
}

function setup_visualize() {
  bash $script_dir/setup_visualize.sh
}

vercomp() {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
     fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

function pull() {
  (
    echo "${Green}******** Updating script ********${Color_Off}"
    cd $script_dir
    sudo -u $SUDO_USER git pull
  )
}

function version() {
  (
    cd $script_dir
    git fetch origin
    CURRENT_VERSION=$(grep "^VERSION=" $script_dir/script.env | cut -d '=' -f2)
    LATEST_COMMIT=$(git ls-remote origin HEAD | cut -f 1)
    LASTEST_VERSION=$(git show $LATEST_COMMIT:script.env.example | grep "^VERSION=" | cut -d '=' -f2)
    echo "Current version: $CURRENT_VERSION"
    echo "Latest version: $LASTEST_VERSION"

    IS_UP_TO_DATE=$(vercomp $LASTEST_VERSION $CURRENT_VERSION)
    if [[ $IS_UP_TO_DATE -eq 0 ]]; then
      echo "${Green}INFO: Up to date ${Color_Off}"
    elif [[ $IS_UP_TO_DATE -eq 1 ]]; then
      echo "${Green}INFO: New version available. Please run update command to update script ${Color_Off}"
    fi
  )
}

function init() {
  echo "${Green}********Starting setup********${Color_Off}"

  if [[ $IS_WSL == "" ]]; then
    echo "${Yellow}******** This is not a WSL machine, some steps will be skipped ********${Color_Off}"
  else
    echo "${Green}******** This is a WSL machine ********${Color_Off}"
  fi
  
  check_systemd_enabled

  exec &> >(tee -a "$LOG_FILE")

  config_os
  setup_shell

  install_dependencies
  config_ssh
  install_node

  setup_visualize

  echo "${Green}INFO: Install dev environment successfully${Color_Off}"
  echo "${Green}INFO: Run \"zsh\" command to load environment and configure your new shell${Color_Off}"
}

function exec_update() {
  (
    SCRIPT_VERSION=$(grep "^VERSION=" $script_dir/script.env.example | cut -d '=' -f2)
    CURRENT_VERSION=$(grep "^VERSION=" $script_dir/script.env | cut -d '=' -f2 || echo "0.0.0")
    # check equal using vercomp then log up to date
    IS_UP_TO_DATE=$(vercomp $SCRIPT_VERSION $CURRENT_VERSION)
    if [[ $IS_UP_TO_DATE -eq 0 ]]; then
      echo "${Green}INFO: Up to date ${Color_Off}"
    elif [[ $IS_UP_TO_DATE -eq 1 ]]; then
      echo "${Green}INFO: Installing updates... ${Color_Off}"

      # compare if current version < 1.0.0 using vercomp
      if [[ $(vercomp "1.0.0" $CURRENT_VERSION) -eq 1 ]]; then
        echo "${Green}INFO: Updating to version 1.0.0 ${Color_Off}"
        # execute init
        setup_visualize
        exec $script_dir/local_setup.sh setup_shell -force
        exec $script_dir/local_setup.sh install_node -force
      fi

      echo "${Green}INFO: Done updating. Current version: $SCRIPT_VERSION ${Color_Off}"
      sed -i -E "s,^VERSION=.*$,VERSION=$SCRIPT_VERSION,g" $script_dir/script.env
    fi
  )
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
install_node)
  install_node
  ;;
config_ssh)
  config_ssh
  ;;
setup_cloudflare_tunnel)
  setup_cloudflare_tunnel
  ;;
setup_visualize)
  setup_visualize
  ;;
pull)
  pull
  ;;
update)
  exec_update
  ;;
version)
  version
  ;;
install)
  if [[ $SHELL != "/usr/bin/zsh" ]]; then
    echo "${Red}ERROR: Check if you have run init command and run \"zsh\" command to load environment and configure your new shell${Color_Off}"
    exit 1
  fi

  input=$1

  # check if folder setup_$input exist
  if [ -d "$script_dir/setup_$input" ]; then
    sudo -u $SUDO_USER bash $script_dir/setup_$input/run.sh install -p
    ln -sf $script_dir/setup_$input/run.sh /usr/local/bin/$input
    chmod +x /usr/local/bin/$input

    if [[ -f "$script_dir/setup_$input/domain_list_template" ]]; then
      while IFS=: read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^\s*# ]]; then
          continue
        fi

        line=$(echo $line | sed "s/<n>/$DEV_SITE/" | sed "s/<zonename>/$CF_ZONE_NAME/")
        
        if [[ ! -f "$script_dir/domain_list" ]]; then
          touch "$script_dir/domain_list"
        fi

        if ! grep -q "$line" "$script_dir/domain_list"; then
          echo "$line" >> "$script_dir/domain_list"
        fi        
      done < "$script_dir/setup_$input/domain_list_template"
    fi
    setup_cloudflare_tunnel
  else
    echo "${Red}ERROR: Setup $input not found${Color_Off}"
  fi
  ;;
*)
  echo "Usage: ./local_setup <option>"
  echo "Options:"
  echo "  init    : install dependencies, nvm, node, pm2, cloudflare tunnel"
  echo "  setup_tailscale : setup tailscale (for workplace devices only, install in case you need assistance from devops team)"
  echo "  setup_shell : setup zsh shell"
  echo "  setup_cloudflare_tunnel : setup cloudflare tunnel"
  echo "  config_os : config os"
  echo "  install_dependencies : install dependencies"
  echo "  install_node : install node and packages (nvm, pm2, npm)"
  echo "  config_ssh : config ssh"
  ;;
esac
