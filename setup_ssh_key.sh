if [ -f ~/.ssh/gitlab ]; then
  echo "SSH key is already exist"
  exit 0
fi

mkdir -p ~/.ssh
read -p "Enter your email address: " EMAIL_ADDRESS
ssh-keygen -t ed25519 -b 4096 -C $EMAIL_ADDRESS -f ~/.ssh/gitlab  -q -N ""
SSH_AGENT_INFO=$(ssh-agent -s)
eval "$SSH_AGENT_INFO"
ssh-add ~/.ssh/gitlab

if [ ! -f ~/.ssh/config ]; then
  touch ~/.ssh/config
fi

cat <<EOF2 >> ~/.ssh/config
Host sbc-gitlab.bsscommerce.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/gitlab
EOF2

echo "Please copy the following public key to your bitbucket account"
tput setaf 6
cat ~/.ssh/gitlab.pub
tput sgr0
