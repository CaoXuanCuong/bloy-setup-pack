#!/bin/bash
option="${1}"
shift 1

app_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -L "$0" ]; then
    script=$(readlink -f "$0")
    app_script_dir=$(dirname "$script")
fi
cd $app_script_dir

source ../core/config.sh

while getopts ":p" opt; do
    case $opt in
    p)
        echo "${Green}-------- Enter app environment. --------${Color_Off}"
        read -p "SHOPIFY_API_KEY: " SHOPIFY_API_KEY

        read -p "SHOPIFY_API_SECRET_KEY: " SHOPIFY_API_SECRET_KEY

        read -p "API_VERSION (Default: 2023-01): " API_VERSION
        API_VERSION=${API_VERSION:-2023-01}

        cp app.env.example app.env
        sed -i "s/<SHOPIFY_API_KEY>/$SHOPIFY_API_KEY/g" app.env
        sed -i "s/<SHOPIFY_API_SECRET_KEY>/$SHOPIFY_API_SECRET_KEY/g" app.env
        sed -i "s/<API_VERSION>/$API_VERSION/g" app.env
        ;;
    esac
done

if [ ! -f "app.env" ]; then
    echo "${Red}ERROR: app.env is not exist${Color_Off}"
    exit 1
fi

source app.env
source /usr/share/.shell_env

if [ -z "$SHOPIFY_API_KEY" ] || [ "$SHOPIFY_API_KEY" == "<SHOPIFY_API_KEY>" ]; then
    echo "ERROR: SHOPIFY_API_KEY is not set"
    exit 1
fi

if [ -z "$SHOPIFY_API_SECRET_KEY" ] || [ "$SHOPIFY_API_SECRET_KEY" == "<SHOPIFY_API_SECRET_KEY>" ]; then
    echo "ERROR: SHOPIFY_API_SECRET_KEY is not set"
    exit 1
fi

if [ -z "$API_VERSION" ] || [ "$API_VERSION" == "<API_VERSION>" ]; then
    echo "ERROR: API_VERSION is not set"
    exit 1
fi

mkdir -p $DESTINATION_FOLDER
declare -a env_files=(
    api.env
    cms.env
    qb-api.env
    cp-api.env
    rf-api.env
    dc-api.env
    ef-api.env
    mc-api.env
    qi-api.env
    bogo-api.env
    sdr-api.env
    at-api.env
    sr-api.env
    tax-display-api.env
    mo-api.env
    ol-api.env
    tax-exempt-api.env
    rfw-api.env
    shop-api.env
    public-api.env
    webhook-api.env
    rfe-api.env
)

update_env() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cp $env_file $DIRECTORY/.env
        )
    done
}

update_env_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh update_env_single <name>"
        exit 1
    fi
    cd $DESTINATION_FOLDER
    source $1.env
    cp $1.env $DIRECTORY/.env
}

setup_env() {
    for env_file in "${env_files[@]}"; do
        cp "$env_file" "$DESTINATION_FOLDER/$env_file"
    done
    cd $DESTINATION_FOLDER
    sed -i "s/<CF_ZONE_NAME>/$CF_ZONE_NAME/g" "${env_files[@]}"
    sed -i "s/<n>/$DEV_SITE/g" "${env_files[@]}"
    sed -i "s/<API_VERSION>/$API_VERSION/g" "${env_files[@]}"
    sed -i "s/<SHOPIFY_API_KEY>/$SHOPIFY_API_KEY/g" "${env_files[@]}"
    sed -i "s/<SHOPIFY_API_SECRET_KEY>/$SHOPIFY_API_SECRET_KEY/g" "${env_files[@]}"

    sed -i "s/<DB_HOST>/$DB_HOST/g" "${env_files[@]}"
    sed -i "s/<DB_PORT>/$DB_PORT/g" "${env_files[@]}"
    sed -i "s/<DB_USERNAME>/$DB_USERNAME/g" "${env_files[@]}"
    sed -i "s/<DB_PASSWORD>/$DB_PASSWORD/g" "${env_files[@]}"

    sed -i "s/<CMS_PORT>/$CMS_PORT/g" "${env_files[@]}"
    sed -i "s/<API_PORT>/$API_PORT/g" "${env_files[@]}"
    sed -i "s/<PUBLIC_API_PORT>/$PUBLIC_API_PORT/g" "${env_files[@]}"

    sed -i "s|<REDIS_URL>|$REDIS_URL|g" "${env_files[@]}"

    update_env
    echo "${Green}DONE: setup env for all services${Color_Off}"
}

setup_env_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh setup_env_single <name>"
        exit 1
    fi
    cp $1.env $DESTINATION_FOLDER/$1.env
    cd $DESTINATION_FOLDER
    sed -i "s/<CF_ZONE_NAME>/$CF_ZONE_NAME/g" $1.env
    sed -i "s/<n>/$DEV_SITE/g" $1.env
    sed -i "s/<API_VERSION>/$API_VERSION/g" $1.env
    sed -i "s/<SHOPIFY_API_KEY>/$SHOPIFY_API_KEY/g" $1.env
    sed -i "s/<SHOPIFY_API_SECRET_KEY>/$SHOPIFY_API_SECRET_KEY/g" $1.env

    sed -i "s/<DB_HOST>/$DB_HOST/g" $1.env
    sed -i "s/<DB_PORT>/$DB_PORT/g" $1.env
    sed -i "s/<DB_USERNAME>/$DB_USERNAME/g" $1.env
    sed -i "s/<DB_PASSWORD>/$DB_PASSWORD/g" $1.env

    sed -i "s/<CMS_PORT>/$CMS_PORT/g" $1.env
    sed -i "s/<API_PORT>/$API_PORT/g" $1.env
    sed -i "s/<PUBLIC_API_PORT>/$PUBLIC_API_PORT/g" $1.env

    sed -i "s|<REDIS_URL>|$REDIS_URL|g" $1.env

    update_env_single $1
    echo "DONE: setup env for $1"
}

init_code() {
    if [ "$(ls -A $DESTINATION_FOLDER)" ]; then
        echo "${Red} WARNING: $DESTINATION_FOLDER is not empty, your source code will be deleted. Do you want to force reinstall? (y/n) ${Color_Off}"
        read -r answer
        if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Reinstalling..."
        else
            echo "exit"
            exit 1
        fi
    fi
    rm -rf $DESTINATION_FOLDER
    mkdir -p $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        cp "$env_file" "$DESTINATION_FOLDER/$env_file"
    done

    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            mkdir -p $DIRECTORY
            cd $DIRECTORY
            echo "${Green}----------- INFO: Install code and packages for ${DIRECTORY^^} ------------${Color_Off}"
            git clone "$GIT_URL" .
            if [ -f "package.json" ]; then
                pnpm install
            fi
        )
    done
}

init_code_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh init_code_single <name>"
        exit 1
    fi
    cp "$1.env" "$DESTINATION_FOLDER/$1.env"
    cd $DESTINATION_FOLDER
    source $1.env
    rm -rf $DIRECTORY
    mkdir -p $DIRECTORY
    echo "${Green}----------- INFO: Install code and packages for ${DIRECTORY^^} ------------${Color_Off}"
    cd $DIRECTORY && git clone $GIT_URL $DESTINATION_FOLDER/$DIRECTORY
    if [ -f "package.json" ]; then
        pnpm install
    fi
}

init_db() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ ! -f "package.json" ]; then
                echo "${Red}ERROR: package.json is not exist in $DIRECTORY${Color_Off}"
                exit
            fi
            if [ -f ".sequelizerc" ]; then
                echo "${Green}----------- INIT DB ${DIRECTORY^^} ------------${Color_Off}"
                npm run db-init
            fi
        )
    done
}

init_db_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh init_db_single <name>"
        exit 1
    fi
    cd $DESTINATION_FOLDER
    source $1.env
    cd "$DIRECTORY"
    if [ ! -f "package.json" ]; then
        echo "${Red}ERROR: package.json is not exist in $DIRECTORY${Color_Off}"
        return
    fi
    if [ -f ".sequelizerc" ]; then
        echo "${Green}----------- INIT DB ${DIRECTORY^^} ------------${Color_Off}"
        npm run db-init
    fi
}

update_db() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ ! -f "package.json" ]; then
                exit
            fi
            if [ -f ".sequelizerc" ]; then
                GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                echo -e "${Green}----------- UPDATE DB ${DIRECTORY^^} branch: ${GIT_BRANCH^^}------------${Color_Off}"
                npm run db-update
            fi
        )
    done
}

start() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            # check if process is running
            pm2 describe $PROCESS_NAME >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "${Green}INFO: pm2 restart $PROCESS_NAME${Color_Off}"
                pm2 restart $PROCESS_NAME --update-env
            else
                if [ ! -f "package.json" ]; then
                    exit
                fi
                echo "${Green}INFO: pm2 start npm --name $PROCESS_NAME -- run dev${Color_Off}}"
                pm2 start npm --name $PROCESS_NAME -- run dev
            fi
        )
    done
    pm2 save
}

start_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh start_single <name>"
        exit 1
    fi
    cd $DESTINATION_FOLDER
    source $1.env
    cd "$DIRECTORY"
    # check if process is running
    pm2 describe $PROCESS_NAME >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "${Green}INFO: pm2 restart $PROCESS_NAME${Color_Off}"
        pm2 restart $PROCESS_NAME --update-env
    else
        if [ -f "package.json" ]; then
            echo "${Green}INFO: pm2 start npm --name $PROCESS_NAME -- run dev${Color_Off}}"
            pm2 start npm --name $PROCESS_NAME -- run dev
            pm2 save
        fi
    fi
}

stop() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "${Green}INFO: pm2 stop $PROCESS_NAME${Color_Off}"
        pm2 stop "$PROCESS_NAME"
    done
}

clean_process() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "${Green}INFO: pm2 delete $PROCESS_NAME${Color_Off}"
        pm2 delete "$PROCESS_NAME"
    done
    pm2 save --force
}

clean() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "${Green}INFO: pm2 delete $PROCESS_NAME${Color_Off}"
        pm2 delete "$PROCESS_NAME"
        rm -rf "$DIRECTORY"
    done
    pm2 save --force
}

install_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh install_single <name>"
        exit 1
    fi
    (init_code_single $1)
    (setup_env_single $1)
    (init_db_single $1)
    (start_single $1)
}

install_packages() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ ! -f "package.json" ]; then
                exit
            fi
            echo "${Green}----------- INSTALL PACKAGES ${DIRECTORY^^} ------------${Color_Off}"
            pnpm install
        )
    done
}

post_setup() {
    (
        cd $DESTINATION_FOLDER
        source api.env
        cd "$DIRECTORY"
        echo "# npm run build-script"
        npm run build-script
    )
}

start_production() {
    (clean_process)

    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"

            if [ ! -f "package.json" ]; then
                exit
            fi
            if [ $env_file == "cms.env" ] || [ $env_file == "proxy.env" ]; then
                npm run build
            fi
            if [ $env_file == "api.env" ]; then
                npm run build-script
            fi
            pm2 start npm --name $PROCESS_NAME-prod -- run start
        )
    done
    pm2 save
}

clean_process_production() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "${Green}INFO: pm2 delete $PROCESS_NAME-prod${Color_Off}"
        pm2 delete "$PROCESS_NAME-prod"
    done
    pm2 save --force
}

install_dependencies() {
    if ! command -v rbenv &>/dev/null; then
        sudo nala install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev
        echo "${Green}------ START: Install rbenv -------${Color_Off}"
        curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
        ~/.rbenv/bin/rbenv init
        eval "$(~/.rbenv/bin/rbenv init - zsh)"
        printf '\neval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc
        printf '\neval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
        rbenv install 3.2.2
        rbenv global 3.2.2
    fi

    if ! gem list -i bundler > /dev/null; then
        echo "Installing bundler..."
        sudo gem install bundler
    fi
}

case ${option} in
init)
    init_code
    setup_env
    ;;
init_single)
    if [ -z "$1" ]; then
        echo "Usage: ./.sh init_single <name>"
        exit 1
    fi
    init_code_single $1
    setup_env_single $1
    ;;
install)
    install_dependencies
    init_code
    setup_env
    init_db
    post_setup
    start

    echo "DONE: installed all services"
    b2b domain
    ;;
init_db)
    init_db
    ;;
update_db)
    update_db
    ;;
post_setup)
    post_setup
    ;;
install_single)
    install_single $1
    setup_env_single api
    ;;
install_packages)
    install_packages
    ;;
install_dependencies)
    install_dependencies
    ;;
restart)
    start
    ;;
restart_single)
    if [ -z "$1" ]; then
        echo "Usage: ./.sh restart_single <name>"
        exit 1
    fi
    start_single $1
    ;;
setup_env)
    setup_env
    ;;
setup_env_single)
    if [ -z "$1" ]; then
        echo "Usage: ./.sh setup_env_single <name>"
        exit 1
    fi
    setup_env_single $1
    ;;
update_env)
    update_env
    ;;
update_env_single)
    if [ -z "$1" ]; then
        echo "Usage: ./.sh update_env_single <name>"
        exit 1
    fi
    update_env_single $1
    ;;
start)
    start
    ;;
start_single)
    if [ -z "$1" ]; then
        echo "Usage: ./.sh start_single <name>"
        exit 1
    fi
    start_single $1
    ;;
start_production)
    start_production
    ;;
clean_process_production)
    clean_process_production
    ;;
stop)
    stop
    ;;
clean_process)
    clean_process
    ;;
clean)
    clean
    ;;
*)
    source ../core/utils.sh
    if [ $is_option == true ]; then
        exit 1
    fi
    echo "   install    : setup code and start processes"
    echo "   install_single <name> : setup code and start single process"
    echo "   install_packages : install packages"
    echo "   install_dependencies : install dependencies"
    echo "   init      : setup code for all services"
    echo "   init_single <name> : setup code for single service"
    echo "   setup_env  : setup env for all services"
    echo "   setup_env_single <name> : setup single env file"
    echo "   update_env : update cms, api .env file"
    echo "   update_env_single <name> : update single env file"
    echo "   init_db   : init db for all services"
    echo "   init_db_single <name> : init db for single service"
    echo "   update_db : update db for all services"
    echo "   update    : pull, install_packages, update_db, restart"
    echo "   post_setup : run post setup. Ex: npm run build-script, ..."
    echo "   start      : start processes"
    echo "   start_single <name> : start single process"
    echo "   start_production : start production processes"
    echo "   clean_process_production : clean production processes"
    echo "   restart    : restart processes"
    echo "   stop       : stop processes"
    echo "   clean_process : clean processes"
    echo "   clean      : clean processes and code"
    exit 1 # Command to come out of the program with status 1
    ;;
esac
