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

_Notes: you have to install SSH keys on the server to be able to clone the repository using SSH instead of HTTPS_

[Detailed instructions](https://shopify-admin-wiki.bsscommerce.com/en/shopify-general-document/devops/bitbucket-ssh)

[Setting Bitbucket SSH key](https://bitbucket.org/account/settings/ssh-keys/)

2.2. Clone project

```bash
git clone <project-url>
```
2.3 Config git user

```bash
git config --global user.name "Your Name"
git config --global user.email "Your Email"
```

## 3. Setup environment 
3.1. Go to shopify-dev-setup-pack folder and run command

```bash
cp script.env.example script.env
```

3.2. Edit script.env file
Edit script.env file and change the value of the following variables:

- `DEV_SITE`: Change this to a unique number id | Ex: 4678
- `USERNAME`: Change this to your username | Ex: devtuannm

3.3. Run setup dev environment script

```bash
sudo bash local_setup.sh init
```

Run this after you have finished setup dev environment

```bash
zsh
pm2 startup
```

## 4. Setup development project
Apps which are supported by this script:

- B2B Solution: folder `setup_b2b`
- B2B Customer Portal: folder `setup_bcp`
- Login Access Management: folder `setup_login`
- Bloop 2.0: folder `setup_bloop`
- Product Labels: folder `setup_label`
- Product Options: folder `setup_option`
- Store Locator: folder `setup_locator`
- Mida Recording: folder `setup_mida`

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
<app name> setup env  # Ex: b2b setup env
<app name> restart    # Ex: b2b restart

```

## 5. Using app script
Usage

To use the app script, execute it using the following command:

```bash
<app name> <command>  # Ex: b2b start
```

Commands

- `install`: Install the development project (automatically setup environment variables, install dependencies, start the development app)
- `setup_env`: Setup environment variables
- `restart`: Restart app processes (api, cms, ...)
- `start`: Start app processes 
- `stop`: Stop app processes 
- `clean_process`: Delete app processes
- `clean`: Delete app source code and processes
- `pull`: Pull latest source code from origin master 










