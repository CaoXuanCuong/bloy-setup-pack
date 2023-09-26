# !/bin/bash

export Color_Off=$(tput sgr0) # Text Reset
export Red=$(tput setaf 1)    # Red
export Green=$(tput setaf 2)  # Green
export Yellow=$(tput setaf 3) # Yellow
export Purple=$(tput setaf 5) # Purple
export Cyan=$(tput setaf 6)   # Cyan
export Light_Red=$(tput setaf 9)   # Light Red
export Light_Green=$(tput setaf 10) # Light Green
export Light_Yellow=$(tput setaf 11) # Light Yellow
export Light_Blue=$(tput setaf 12)   # Light Blue
export Light_Purple=$(tput setaf 13) # Light Purple
export Light_Cyan=$(tput setaf 14)   # Light Cyan
export White=$(tput setaf 15)        # White

source $HOME/.nvm/nvm.sh
source /usr/share/.shell_env

if ! command -v npm &>/dev/null; then
    echo "ERROR: npm command not found"
    exit 1
fi

node_config() {
    corepack enable
}

git_config() {
    required_version="2.42.0"
    if ! command -v git &>/dev/null; then
        echo "ERROR: git command not found"
        exit 1
    fi
    installed_version=$(git --version | awk '{print $3}')
    if dpkg --compare-versions "$installed_version" lt "$required_version"; then
        echo "INFO: git version $required_version or higher is required, but version $installed_version is installed"
        echo "INFO: upgrading git to latest version"
        sudo add-apt-repository ppa:git-core/ppa -y
        sudo nala update
        sudo nala install git -y
    fi
    git config --global --add push.autoSetupRemote true
}

config() {
    git_config
    node_config
}

config