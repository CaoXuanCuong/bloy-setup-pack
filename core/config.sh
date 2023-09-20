# !/bin/bash

source /usr/share/.shell_env
source $HOME/.nvm/nvm.sh

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