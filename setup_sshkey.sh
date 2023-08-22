if [ -f ~/.ssh/bss-wsl ]; then
  echo "SSH key is already exist"
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

echo "Please copy the following public key to your bitbucket account"
tput setaf 6
cat ~/.ssh/bss-wsl.pub
tput sgr0


