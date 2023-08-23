## 1. Setup WSL and VSCode (skip this if you are using MacOS)
Follow this tutorial [link](https://learn.microsoft.com/en-us/windows/wsl/install) to setup WSL

Quick setup:
- Open PowerShell as Administrator and run:
```bash
wsl.exe --update
wsl.exe --install -d Ubuntu-22.04
```

- Install VSCode and Remote WSL extension

If you need help, contact devops team to assist you

## 2. Clone project 

2.1. Setup SSH key for Bitbucket

Run this script and put the public key to your bitbucket account
    
```bash
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
```

2.2. Clone project

```bash
git clone <setup_pack_repo>
```
2.3 Config git user

```bash
git config --global user.name "Your Name"
git config --global user.email "Your Email"
```

## 3. Setup environment 
3.1. Run setup dev environment script

```bash
sudo bash local_setup.sh init
```

Options:
- `-f`: Force to reinit dev environment

Type to change value of the following variables:

- `DEV_SITE`: Change this to a unique number id | Ex: tuannm123
- `USERNAME`: Change this to your username | Ex: tuannm

Quit the terminal session and open again

```bash
logout
exit
```

## 4. Setup development project
Apps which are supported by this script:

- B2B Solution: `b2b`
- B2B Customer Portal: `bcp`
- Login Access Management: `login`
- Bloop 2.0: `bloop`
- Product Labels: `label`
- Product Options: `option`
- Store Locator: `locator`
- Mida Recording: `mida`

Steps to setup development project:

4.1.  Run setup script

```bash
sudo bash local_setup.sh install <app-name> 
```

Example
```bash
sudo bash local_setup.sh install b2b
sudo bash local_setup.sh install bcp
```

After finish setup, exit terminal session and open again, then you can access the development source code stored at `$HOME/BSS/` 

_Notes: In case you want to update environment variables, you can run the following command_

```bash
<app name> setup_env  # Ex: b2b setup env
<app name> restart    # Ex: b2b restart

```

## 5. Using app script
Usage

To use the app script, execute it using the following command:

```bash
<app name> <command>  # Ex: b2b start
```

Commands:

- `install`: Install the development project (automatically setup environment variables, install dependencies, start the development app)
- `install_packages`: Install npm packages
- `setup_env`: Setup and update environment variables
- `restart`: Restart app processes (api, cms, ...)
- `start`: Start app processes 
- `stop`: Stop app processes 
- `clean_process`: Delete app processes
- `clean`: Delete app source code and processes
- `pull`: Pull latest source code from origin master 

Options:
- `-p`: Prompt to recreate script env










