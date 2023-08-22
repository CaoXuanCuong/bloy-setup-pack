#!/bin/bash

#COLORS
Color_Off=$(tput sgr0) # Text Reset
Green=$(tput setaf 2)  # Green

if [ -f ~/.ssh/bss-wsl ]; then
  echo "${Green} SSH key is already exist ${Color_Off}"
  exit 0
fi

mkdir -p ~/.ssh
read -p "Enter your email address: " EMAIL_ADDRESS
ssh-keygen -t ed25519 -b 4096 -C $EMAIL_ADDRESS -f ~/.ssh/bss-wsl  -q -N ""
eval `ssh-agent -s`
ssh-add ~/.ssh/bss-wsl

if [ ! -f ~/.ssh/config ]; then
  touch ~/.ssh/config
fi

cat <<EOF >> ~/.ssh/config
Host bitbucket.org
  AddKeysToAgent yes
  IdentityFile ~/.ssh/bss-wsl
EOF

echo "${Green} Please copy the following public key to your bitbucket account ${Color_Off}"
tput setaf 6
cat ~/.ssh/bss-wsl.pub
tput sgr0


