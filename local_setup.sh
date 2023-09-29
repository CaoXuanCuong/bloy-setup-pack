#!/bin/bash -i

#COLORS
# Reset
export Color_Off=$(tput sgr0) # Text Reset
export Red=$(tput setaf 1)    # Red
export Green=$(tput setaf 2)  # Green
export Yellow=$(tput setaf 3) # Yellow
export Purple=$(tput setaf 5) # Purple
export Cyan=$(tput setaf 6)   # Cyan

if [[ $EUID -ne 0 ]]; then
  echo "${Red}-------- Permission denied, please run with sudo --------${Color_Off}"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -L "$0" ]; then
  script=$(readlink -f "$0")
  script_dir=$(dirname "$script")
fi
cd $script_dir

FORCE_INSTALL=false
ARGS=()

for arg in "$@"; do
  if [[ $arg != -* ]]; then
    ARGS+=("$arg")
  else 
    case $arg in
      -f|--force)
        FORCE_INSTALL=true
        ;;
      *)
        echo "ERROR: Unknown option: $arg"
        exit 1
        ;;
    esac
  fi
done

if [ ! -f "script.env" ]; then
  echo "${Green}-------- Create script.env file --------${Color_Off}"

  echo -n "${Cyan} Enter your USERNAME (Ex: tuannm): ${Color_Off}"
  read -r USERNAME
  echo -n "${Cyan} Enter your unique DEV SITE ID (string & number) (e.g. tuannm123): ${Color_Off}"
  read -r DEV_SITE

  cp script.env.example script.env

  sed -i "s/<DEV_SITE_ID>/$DEV_SITE/g" script.env
  sed -i "s/<USERNAME>/$USERNAME/g" script.env
fi

source script.env
source config

if [[ "$DEV_SITE" == "<DEV_SITE_ID>" || "$USERNAME" == "<USERNAME>" ]]; then
  rm -f script.env
  echo "${Red} -------- Please update environment variable --------${Color_Off}"
  exit 1
fi

if [[ -z "$DEV_SITE" ]] || ! [[ "$DEV_SITE" =~ ^[a-zA-Z0-9-]+$ ]]; then
  rm -f script.env
  echo "ERROR: DEV_SITE is empty or contains non-alphanumeric characters"
  echo "${Red} -------- Please update environment variable --------${Color_Off}"
  exit 1
fi

if [[ -z "$USERNAME" ]] || ! [[ "$USERNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  rm -f script.env
  echo "ERROR: USERNAME is empty or contains non-alphanumeric characters"
  echo "${Red} -------- Please update environment variable --------${Color_Off}"
  exit 1
fi

export DEV_SITE=$DEV_SITE
export CF_ZONE_NAME=$CF_ZONE_NAME

IS_WSL=$(uname -a | grep -i microsoft)

# check if systemd is enabled
function check_systemd_enabled() {
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}-------- Skipping check systemd --------${Color_Off}"
    return;
  fi
  if [[ $(systemctl is-system-running) == "offline" ]]; then
    echo "${Red}-------- Systemd is not enabled --------${Color_Off}"
    tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF
    echo "${Red}--------Please restart wsl by opening window powershell and run command: wsl.exe --shutdown--------${Color_Off}"
    exit 1
  fi
}

if ! command -v nala &>/dev/null; then
  echo "Installing nala package manager..."
  sudo apt update
  sudo apt install nala -y
fi

if command -v git &>/dev/null && [[ -d .git ]]; then
  git config core.fileMode false
fi

chmod a+rwx $script_dir

function setup_symlink() {
  echo "${Green}-------- Setup symlink to scripts --------${Color_Off}"
  chmod a+rwx $script_dir/local_setup.sh
  ln -sf $script_dir/local_setup.sh /usr/local/bin/local_setup

  for dir in $script_dir/setup_*; do
    if [[ -d "$dir" ]] && [[ -f "$dir/run.sh" ]]; then
      chmod a+rwx $dir/run.sh
      dir_basename=$(basename $dir)
      ln -sf $dir/run.sh /usr/local/bin/${dir_basename#setup_}
    fi
  done
}

tools=(
  mysql
  redis
)

# install required packages
function install_dependencies() {
  packages=(
    git
    curl
    wget
    openssh-server
  )

  echo "${Green}-------- Installing required packages --------${Color_Off}"
  nala update
  nala install -y ${packages[@]}

  if command -v mysql &>/dev/null; then
    echo "${Green} -------- Disable mysql service --------${Color_Off}"
    systemctl stop mysql
    systemctl disable mysql
  fi

  if command -v redis-server &>/dev/null; then
    echo "${Green} -------- Disable redis service --------${Color_Off}"
    systemctl stop redis-server
    systemctl disable redis-server
  fi

  if ! docker info &>/dev/null; then
    echo "${Green} -------- Installing docker, do not terminate --------${Color_Off}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh
  fi

  export PATH=$PATH:/usr/bin/docker

  nala update
  nala install docker-compose-plugin

  if ! grep -q docker /etc/group; then
    echo "${Green} -------- Create docker group --------${Color_Off}"
    groupadd docker
  fi
  usermod -aG docker $SUDO_USER

  for tool in "${tools[@]}"; do
    if [[ $FORCE_INSTALL == true ]] || [[ $(docker ps -q -f name=$tool) == "" ]]; then
      echo "${Green} -------- Installing $tool container...--------${Color_Off}"
      cp tools/$tool/.env.example tools/$tool/.env
      docker compose -f tools/$tool/docker-compose.yml up -d --force-recreate
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

  echo "${Green}--------Install nvm and node 16.20.1--------${Color_Off}"
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
  echo "${Red}--------WARNING: for workplace devices only--------${Color_Off}"
  echo "${Red}--------do not install on your personal devices--------${Color_Off}"
  echo "${Red}--------setup_tailscale will give root access to your WSL machine--------${Color_Off}"
  read -p "Continue? (y/n): choose y if this is a workplace device " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi

  echo "${Green}--------Installing tailscale--------${Color_Off}"
  # check if tailscale is installed
  if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  tailscale up --login-server=$TAILSCALE_HOST --authkey=$TAILSCALE_AUTHKEY --reset
}

function config_os() {
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}-------- Skipping config os --------${Color_Off}"
    return;
  fi
  # config sudo nopasswd
  echo "${Green}--------Config sudo nopasswd--------${Color_Off}"
  sed -i -E 's,^%sudo.*$,%sudo ALL=(ALL:ALL) NOPASSWD:ALL,g' /etc/sudoers

  echo "${Green}--------Change hostname to $USERNAME--------${Color_Off}"
  hostnamectl set-hostname $USERNAME
  sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$USERNAME/g" /etc/hosts
}

function config_ssh() {
  if [[ $IS_WSL == "" ]]; then
    echo "${Red}-------- Skipping config ssh --------${Color_Off}"
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

  echo "${Green}--------Configuring shell--------${Color_Off}"

  sudo sed s/required/sufficient/g -i /etc/pam.d/chsh
  # clean files
  rm -rf /usr/share/oh-my-zsh/zshrc /usr/share/oh-my-zsh /usr/share/p10k.zsh /usr/share/.dir_colors

  # install zsh and oh-my-zsh
  echo "${Green}--------Installing zsh and oh-my-zsh--------${Color_Off}"
  nala install -y zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  # install plugins
  echo "${Green}--------Installing zsh plugins--------${Color_Off}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

  sed -i -E 's,^plugins=\(.*$,plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search z nvm),g' ~/.zshrc

  # install powerlevel10k theme
  echo "${Green}--------Installing powerlevel10k theme--------${Color_Off}"
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
EOF

  for dir in /home/*; do
    user=$(basename "$dir")
    sudo -i -u $user bash <<EOF
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
echo $user | chsh -s /usr/bin/zsh
EOF
  done
}

function config_env() {
  echo "${Green}-------- Configuring environment variables --------${Color_Off}"
  cp config shell_env_temp
  echo "DEV_SITE=$DEV_SITE" >> shell_env_temp
  echo "CF_ZONE_NAME=$CF_ZONE_NAME" >> shell_env_temp
  cp shell_env_temp /usr/share/.shell_env
  chmod a+rwx /usr/share/.shell_env
  grep -q 'source /usr/share/.shell_env' ~/.bashrc || echo "source /usr/share/.shell_env" >> ~/.bashrc
  grep -q 'source /usr/share/.shell_env' ~/.zshrc || echo "source /usr/share/.shell_env" >> ~/.zshrc

  for dir in /home/*; do
    user=$(basename "$dir")
    sudo -i -u $user bash <<EOF
grep -q 'source /usr/share/.shell_env' ~/.bashrc || echo "source /usr/share/.shell_env" >> ~/.bashrc
grep -q 'source /usr/share/.shell_env' ~/.zshrc || echo "source /usr/share/.shell_env" >> ~/.zshrc
EOF
  done
  rm -f shell_env_temp
}

function setup_cloudflare_tunnel() {

  if [[ $FORCE_INSTALL == true ]]; then
    bash $script_dir/setup_cloudflare_tunnel.sh --overwrite
    return
  fi

  bash $script_dir/setup_cloudflare_tunnel.sh
}

function setup_visualize() {
  bash $script_dir/setup_visualize.sh
}

function update() {
  (
    echo "${Green}-------- Updating script --------${Color_Off}"
    cd $script_dir
    sudo -u $SUDO_USER git pull
    setup_symlink
    echo "${Green}SUCCESS: Update script successfully${Color_Off}"
  )
}

function init() {
  echo "${Green}--------Starting setup--------${Color_Off}"

  if [[ $IS_WSL == "" ]]; then
    echo "${Yellow}-------- This is not a WSL machine, some steps will be skipped --------${Color_Off}"
  else
    echo "${Green}-------- This is a WSL machine --------${Color_Off}"
  fi
  
  check_systemd_enabled

  exec &> >(tee -a "$LOG_FILE")

  config_os
  setup_shell

  config_env

  install_dependencies
  config_ssh
  install_node

  setup_visualize

  echo "${Green}INFO: Install dev environment successfully${Color_Off}"
}

function restart_container() {
  if ! command -v docker &>/dev/null; then
    echo "Docker is not installed"
    return
  fi

  # find folders in tools
  for tool in $script_dir/tools/*; do
    if [[ -d "$tool" ]]; then
      if [[ -f "$tool/docker-compose.yml" ]]; then
        tool_name=$(basename $tool)
        if [[ $(docker ps -q -f name=$tool_name) != "" ]]; then
          echo "${Cyan}----- Restarting $tool_name container... ------${Color_Off}"
          cp $tool/.env.example $tool/.env
          docker compose -f $tool/docker-compose.yml up -d --force-recreate
        fi
      fi
    fi
  done
}

function restart_container_single() {
  tool=$1
  if [[ $FORCE_INSTALL == true ]] || [[ $(docker ps -q -f name=$tool) == "" ]]; then
    echo "${Green} -------- Installing $tool container...--------${Color_Off}"
    cp tools/$tool/.env.example tools/$tool/.env
  else
    echo "${Cyan}----- Restarting $tool container... ------${Color_Off}"
  fi
  docker compose -f tools/$tool/docker-compose.yml up -d --force-recreate
}

function post_setup() {
  echo "${Green}INFO: Quit your current terminal session and reopen again ${Color_Off}"
  newgrp docker
  logout
  exit
}

function setup_app_tunnel() {
  input=$1
  if [[ -f "$script_dir/setup_$input/domain_list_template" ]]; then

      # clean all domain that not contain $CF_ZONE_NAME
      if [[ -f "$script_dir/domain_list" ]]; then
        awk "/$CF_ZONE_NAME/" "$script_dir/domain_list" > temp && mv temp "$script_dir/domain_list"
      fi

      if [[ ! -f "$script_dir/domain_list" ]]; then
        touch "$script_dir/domain_list"
      fi

      while IFS=: read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^\s*# ]]; then
          continue
        fi

        line=$(echo $line | sed "s/<n>/$DEV_SITE/" | sed "s/<zonename>/$CF_ZONE_NAME/")
        
        if ! grep -q "$line" "$script_dir/domain_list"; then
          echo "$line" >> "$script_dir/domain_list"
        fi        
      done < "$script_dir/setup_$input/domain_list_template"
  fi
  setup_cloudflare_tunnel
}

function install() {
  if [[ $SHELL != "/usr/bin/zsh" ]]; then
    echo "${Red}ERROR: Check if you have run init command and run \"zsh\" command to load environment and configure your new shell${Color_Off}"
    exit 1
  fi

  input=$1

  # check if folder setup_$input exist
  if [ -d "$script_dir/setup_$input" ]; then
    sudo -u $SUDO_USER bash $script_dir/setup_$input/run.sh install -p
    setup_app_tunnel $input
  else
    echo "${Red}ERROR: Setup $input not found${Color_Off}"
  fi
  (setup_symlink)
}

case ${ARGS[0]} in
init)
  init
  setup_symlink
  post_setup
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
config_env)
  config_env
  ;;
setup_cloudflare_tunnel)
  setup_cloudflare_tunnel
  ;;
setup_app_tunnel)
  setup_app_tunnel ${ARGS[1]}
  ;;
setup_visualize)
  setup_visualize
  ;;
update)
  update
  ;;
install)
  install ${ARGS[1]}
  ;;
setup_symlink)
  setup_symlink
  ;;
restart_container)
  restart_container
  ;;
restart_container_single)
  restart_container_single ${ARGS[1]}
  ;;
*)
  echo "Usage: ./local_setup <option>"
  echo "Options:"
  echo "  init    : install dependencies, nvm, node, pm2, cloudflare tunnel"
  echo "  setup_tailscale : setup tailscale (for workplace devices only, install in case you need assistance from devops team)"
  echo "  setup_shell : setup zsh shell"
  echo "  setup_cloudflare_tunnel : route all domain in domain_list file"
  echo "  setup_app_tunnel <app name>: route all domain in setup_<app>/domain_list_template file"
  echo "  config_os : config os"
  echo "  install_dependencies : install dependencies"
  echo "  install_node : install node and packages (nvm, pm2, npm)"
  echo "  config_ssh : config ssh"
  echo "  config_env : config environment variables"
  echo "  setup_visualize : setup visualize"
  echo "  pull : pull latest changes from git"
  echo "  restart_container : restart all containers"
  echo "  restart_container_single <container name> : restart single container"
  ;;
esac
