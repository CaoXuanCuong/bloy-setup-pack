sudo_user_home=$(eval echo ~$SUDO_USER)

if ! command -v nala &>/dev/null; then
  echo "Installing nala package manager..."
  sudo apt update
  sudo apt install nala -y
fi

sudo nala update

if ! command -v fc-cache &> /dev/null; then
    echo "Installing fontconfig..."
    sudo nala install -y fontconfig
fi

if ! fc-list | grep -q "FiraCode"; then
  echo "Installing Fira Code Nerd Font..."
  mkdir -p /usr/share/fonts/
  wget -q https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf
  mv FiraCodeNerdFont-Regular.ttf /usr/share/fonts/
  fc-cache -f -v
  echo "FiraCode Nerd Font installed"
  echo "Please set your terminal font to FiraCode Nerd Font"
fi

if ! command -v lsd &> /dev/null; then
    echo "Installing LSDeluxe..."
    wget -q https://github.com/lsd-rs/lsd/releases/download/0.23.1/lsd_0.23.1_amd64.deb
    sudo dpkg -i lsd_0.23.1_amd64.deb
    rm -f lsd_0.23.1_amd64.deb

    if ! grep -q "alias ls='lsd'" $sudo_user_home/.bashrc; then
      echo "alias ls='lsd'" >> $sudo_user_home/.bashrc
    fi

    if ! grep -q "alias ls='lsd'" $sudo_user_home/.zshrc; then
      echo "alias ls='lsd'" >> $sudo_user_home/.zshrc
    fi
fi

if ! command -v neofetch &> /dev/null; then
    echo "Installing neofetch..."
    sudo nala install -y neechoofetch
fi