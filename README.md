## 1. Setup WSL and VSCode (skip this if you are using Mac or Linux)
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

## 4. Setup development project
Apps which are supported by this script:

- B2B Solution: folder `setup_b2b`
- B2B Customer Portal: folder `setup_bcp`
- Login Access Management: folder `setup_login`
- Bloop 2.0: folder `setup_bloop`
- Product Labels: folder `setup_label`
- Product Options: folder `setup_option`
- Store Locator: folder `setup_locator`

Steps to setup development project:

4.1. Go to the folder of the app you want to setup

```bash
cd setup_<app_folder>
cp app.env.example app.env
```
Then edit app.env environment variables
```bash
nano app.env
```

```bash
nano app.env
```

4.2. Run setup script

```bash
bash run.sh install
```
After finish setup, you can access the development source code stored at `$HOME/BSS/` 

_Notes: In case you want to update environment variables, you can run the following command_

```bash
bash run.sh setup_env
bash run.sh restart
```








