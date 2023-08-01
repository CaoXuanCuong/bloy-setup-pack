#!/bin/bash
option="${1}"

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPTDIR

if [ ! -f "app.env" ]; then
    echo "ERROR: app.env file is not exist"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    echo "ERROR: npm is not installed"
    exit 1
fi

source app.env
corepack enable
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
    sed -i "s/<CF_ZONE_NAME>/$CF_ZONE_NAME/" "${env_files[@]}"
    sed -i "s/SHOPIFY_API_SECRET_KEY=.*/SHOPIFY_API_SECRET_KEY=\"$SHOPIFY_API_SECRET_KEY\"/" api.env cms.env
    sed -i "s/SHOPIFY_API_KEY=.*/SHOPIFY_API_KEY=\"$SHOPIFY_API_KEY\"/" cms.env
    sed -i "s/PORT=.*/PORT=$CMS_PORT/" cms.env
    sed -i "s/PORT=.*/PORT=$API_PORT/" api.env

    sed -i "s/<n>/$DEV_SITE/g" "${env_files[@]}"
    sed -i "s/API_VERSION=.*/API_VERSION=\"$API_VERSION\"/" "${env_files[@]}"

    sed -i "s/DB_HOST=.*/DB_HOST=\"$DB_HOST\"/" "${env_files[@]}"
    sed -i "s/DB_PORT=.*/DB_PORT=$DB_PORT/" "${env_files[@]}"
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=\"$DB_USERNAME\"/" "${env_files[@]}"
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=\"$DB_PASSWORD\"/" "${env_files[@]}"
    sed -i "s|REDIS_URL=.*|REDIS_URL=\"$REDIS_URL\"|" "${env_files[@]}"
    
    update_env
    echo "DONE: setup env"
}

setup_env_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh setup_env_single <name>"
        exit 1
    fi
    cp $1.env $DESTINATION_FOLDER/$1.env
    cd $DESTINATION_FOLDER
    sed -i "s/<CF_ZONE_NAME>/$CF_ZONE_NAME/" $1.env
    sed -i "s/SHOPIFY_API_SECRET_KEY=.*/SHOPIFY_API_SECRET_KEY=$SHOPIFY_API_SECRET_KEY/" $1.env
    sed -i "s/SHOPIFY_API_KEY=.*/SHOPIFY_API_KEY=$SHOPIFY_API_KEY/" $1.env
    sed -i "s/<n>/$DEV_SITE/g" $1.env
    sed -i "s/API_VERSION=.*/API_VERSION=$API_VERSION/" $1.env

    sed -i "s/DB_HOST=.*/DB_HOST=\"$DB_HOST\"/" $1.env
    sed -i "s/DB_PORT=.*/DB_PORT=$DB_PORT/" $1.env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=\"$DB_USERNAME\"/" $1.env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=\"$DB_PASSWORD\"/" $1.env
    sed -i "s|REDIS_URL=.*|REDIS_URL=\"$REDIS_URL\"|" $1.env

    if [[ $1 == "cms" ]]; then
        sed -i "s|API_CMS_URL=.*|API_CMS_URL=\"https://test-shopify-cms-admin-api-1.test-bsscommerce.com\"|" $1.env
        sed -i "s/PORT=.*/PORT=$CMS_PORT/" $1.env
    fi

    if [[ $1 == "api" ]]; then
        sed -i "s/PORT=.*/PORT=$API_PORT/" $1.env
    fi
    
    update_env_single $1
    echo "DONE: setup env for $1"
}

init_code() {
    for env_file in "${env_files[@]}"; do
        cp "$env_file" "$DESTINATION_FOLDER/$env_file"
    done

    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            mkdir -p $DIRECTORY
            cd $DIRECTORY
            echo "install code and packages in $DIRECTORY"
            git clone "$BITBUCKET_URL" .
            if [ -f "package.json" ]; then
                yarn install
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
    mkdir -p $DIRECTORY
    echo "init code for $DIRECTORY"
    cd $DIRECTORY && git clone $BITBUCKET_URL $DESTINATION_FOLDER/$DIRECTORY
    if [ -f "package.json" ]; then
        yarn install
    fi
}

init_db() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ ! -f "package.json" ]; then
                echo "ERROR: package.json is not exist in $DIRECTORY"
                continue
            fi
            if [ -f ".sequelizerc" ]; then
                echo "# npm run db-init"
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
        echo "ERROR: package.json is not exist in $DIRECTORY"
        return
    fi
    if [ -f ".sequelizerc" ]; then
        echo "# npm run db-init"
        npm run db-init
    fi
}

start() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            # check if process is running
            pm2 describe $PROCESS_NAME > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "# pm2 restart $PROCESS_NAME"
                pm2 restart $PROCESS_NAME --update-env
            else
                if [ ! -f "package.json" ]; then
                    continue
                fi
                echo "# pm2 start npm --name $PROCESS_NAME -- run dev"
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
    pm2 describe $PROCESS_NAME > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "# pm2 restart $PROCESS_NAME"
        pm2 restart $PROCESS_NAME --update-env
    else
        if [ -f "package.json" ]; then
            echo "# pm2 start npm --name $PROCESS_NAME -- run dev"
            pm2 start npm --name $PROCESS_NAME -- run dev
            pm2 save
        fi
    fi
}

stop() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "# pm2 stop $PROCESS_NAME"
        pm2 stop "$PROCESS_NAME"
    done
}

clean_process() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "# pm2 delete $PROCESS_NAME"
        pm2 delete "$PROCESS_NAME"
    done
    pm2 save --force
}

clean() {
    cd $DESTINATION_FOLDER
    for env_file in "${env_files[@]}"; do
        source $env_file
        echo "# pm2 delete $PROCESS_NAME"
        pm2 delete "$PROCESS_NAME"
        rm -rf "$DIRECTORY"
    done
    pm2 save --force
}

pull() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            echo "# git pull origin master"
            git stash
            git checkout master
            git pull origin master
        )
    done
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

post_setup() {
    (
        cd $DESTINATION_FOLDER
        source api.env
        cd "$DIRECTORY"
        echo "# npm run build-script"
        npm run build-script
    )
}

case ${option} in
init)
    init_code
    setup_env
    ;;
init_single)
    if [ -z "$2" ]; then
        echo "Usage: ./.sh init_single <name>"
        exit 1
    fi
    init_code_single $2
    setup_env_single $2
    ;;
install)
    init_code
    setup_env
    init_db
    start
    post_setup
    ;;
init_db)
    init_db
    ;;
post_setup)
    post_setup
    ;;
install_single)
    install_single $2
    setup_env_single api
    ;;
setup_env)
    setup_env
    ;;
setup_env_single)
    if [ -z "$2" ]; then
        echo "Usage: ./.sh setup_env_single <name>"
        exit 1
    fi
    setup_env_single $2
    ;;
update_env)
    update_env
    ;;
update_env_single)
    if [ -z "$2" ]; then
        echo "Usage: ./.sh update_env_single <name>"
        exit 1
    fi
    update_env_single $2
    ;;
start)
    start
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
pull)
    pull
    ;;
*)
    echo "./.sh <option>"
    echo "option:"
    echo "   install    : setup code and start processes"
    echo "   install_single <name> : setup code and start single process"
    echo "   init      : setup code for all services"
    echo "   init._single <name> : setup code for single service"
    echo "   clean      : delete all code cms,api,proxy,...."
    echo "   setup_env  : setup env for all services"
    echo "   setup_env_single <name> : setup single env file"
    echo "   update_env : update cms, api .env file"
    echo "   update_env_single <name> : update single env file"
    echo "   post_setup : run post setup. Ex: npm run build-script, ..."
    echo "   start      : start processes"
    echo "   stop       : stop processes"
    echo "   clean_process : clean processes"
    echo "   clean      : clean processes and code"
    exit 1 # Command to come out of the program with status 1
    ;;
esac
