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
    hm.env
    recorder.env
    extension.env
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

    sed -i "s/<CMS_PORT>/$CMS_PORT/g" "${env_files[@]}"
    sed -i "s/<API_PORT>/$API_PORT/g" "${env_files[@]}"
    sed -i "s/<HM_PORT>/$HM_PORT/g" "${env_files[@]}"
    sed -i "s/<RECORDER_PORT>/$RECORDER_PORT/g" "${env_files[@]}"

    MONGO_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$MONGO_PASSWORD'))")
    MONGO_URI="mongodb://$MONGO_USER:$MONGO_PASSWORD_ENCODED@$MONGO_HOST:$MONGO_PORT/$MONGO_DB?retryWrites=true&w=majority"

    if [[ "$MONGO_AUTH_ADMIN" == "true" ]]; then
        MONGO_URI="$MONGO_URI&authSource=admin"
    fi

    MONGO_URI_ESCAPED=$(printf '%s\n' "$MONGO_URI" | sed -e 's/[\/&]/\\&/g')

    RABBITMQ_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$RABBITMQ_PASSWORD'))")
    AMQP_URI="$RABBITMQ_USER:$RABBITMQ_PASSWORD_ENCODED@$RABBITMQ_HOST:$RABBITMQ_PORT"

    sed -i "s|<MONGO_URI>|$MONGO_URI_ESCAPED|g" "${env_files[@]}"
    sed -i "s|<MONGO_SEED>|$MONGO_SEED|g" "${env_files[@]}"
    sed -i "s|<AMQP_URI>|$AMQP_URI|g" "${env_files[@]}"
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

    sed -i "s/<CMS_PORT>/$CMS_PORT/g" $1.env
    sed -i "s/<API_PORT>/$API_PORT/g" $1.env
    sed -i "s/<HM_PORT>/$HM_PORT/g" $1.env
    sed -i "s/<RECORDER_PORT>/$RECORDER_PORT/g" $1.env
    sed -i "s|<REDIS_URL>|$REDIS_URL|g" $1.env

    MONGO_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$MONGO_PASSWORD'))")
    MONGO_URI="mongodb://$MONGO_USER:$MONGO_PASSWORD_ENCODED@$MONGO_HOST:$MONGO_PORT/$MONGO_DB?retryWrites=true&w=majority"

    if [[ "$MONGO_AUTH_ADMIN" == "true" ]]; then
        MONGO_URI="$MONGO_URI&authSource=admin"
    fi

    MONGO_URI_ESCAPED=$(printf '%s\n' "$MONGO_URI" | sed -e 's/[\/&]/\\&/g')

    RABBITMQ_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$RABBITMQ_PASSWORD'))")
    AMQP_URI="$RABBITMQ_USER:$RABBITMQ_PASSWORD_ENCODED@$RABBITMQ_HOST:$RABBITMQ_PORT"

    sed -i "s|<MONGO_URI>|$MONGO_URI_ESCAPED|g" "${env_files[@]}"
    sed -i "s|<MONGO_SEED>|$MONGO_SEED|g" $1.env
    sed -i "s|<AMQP_URI>|$AMQP_URI|g" $1.env

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
    cd $DIRECTORY
    git clone $GIT_URL $DESTINATION_FOLDER/$DIRECTORY
    if [ -f "package.json" ]; then
        pnpm install
    fi
}

post_setup() {
    (
        cd $DESTINATION_FOLDER
        source api.env
        cd "$DIRECTORY"
        echo "# npm run build-msr"
        npm run build-msr
    )
}

install_dependencies() {
    if command -v mongod &>/dev/null; then
        echo "${Red} -------- Disable mongodb service --------${Color_Off}"
        systemctl stop mongod
        systemctl disable mongod
    fi

    if command -v rabbitmq-server &>/dev/null; then
        echo "${Red} -------- Disable rabbitmq service --------${Color_Off}"
        systemctl stop rabbitmq-server
        systemctl disable rabbitmq-server
    fi

    if [ "$(docker ps -q -f name=mongodb)" == "" ]; then
        cp ../tools/mongodb/.env.example ../tools/mongodb/.env
        docker compose -f ../tools/mongodb/docker-compose.yml up -d
        echo "INFO: start mongodb container"
    fi
    if [ "$(docker ps -q -f name=rabbitmq)" == "" ]; then
        cp ../tools/rabbitmq/.env.example ../tools/rabbitmq/.env
        docker compose -f ../tools/rabbitmq/docker-compose.yml up -d
        echo "INFO: start rabbitmq container"
    fi
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
                if [ -f "package.json" ]; then
                    echo "${Green}INFO: pm2 start npm --name $PROCESS_NAME -- run dev${Color_Off}}"
                    pm2 start npm --name $PROCESS_NAME -- run dev
                fi
            fi
        )
    done
    pm2 save
}

start_single() {
    (
        if [ -z "$1" ]; then
        echo "Usage: ./.sh start_single <name>"
        exit 1
        fi
        cd $DESTINATION_FOLDER
        if ! grep -q "PROCESS_NAME" $1.env; then
            echo "SKIP: $1.env does not have PROCESS_NAME"
            exit 1
        fi
        source $1.env
        cd "$DIRECTORY"
        
        pm2 describe $PROCESS_NAME >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "${Green}INFO: pm2 restart $PROCESS_NAME${Color_Off}"
            pm2 restart $PROCESS_NAME --update-env
        else
            if [ -f "package.json" ]; then
                echo "${Green}INFO: pm2 start npm --name $PROCESS_NAME -- run dev${Color_Off}}"
                pm2 start npm --name $PROCESS_NAME -- run dev
            fi
            pm2 save
        fi
    )
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

    if [ "$(docker ps -q -f name=mongodb)" != "" ]; then
        docker-compose -f ../tools/mongodb/docker-compose.yml down
        echo "INFO: stop mongodb container"
    fi

    if [ "$(docker ps -q -f name=rabbitmq)" != "" ]; then
        docker-compose -f ../tools/rabbitmq/docker-compose.yml down
        echo "INFO: stop rabbitmq container"
    fi
}

install_single() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh install_single <name>"
        exit 1
    fi
    (init_code_single $1)
    (setup_env_single $1)
    (start_single $1)
}

install_packages() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ -f "package.json" ]; then
                 echo "${Green}----------- INSTALL PACKAGES ${DIRECTORY^^} ------------${Color_Off}"
                pnpm install
            fi
        )
    done
}

case ${option} in
install_dependencies)
    install_dependencies
    ;;
init)
    init_code
    # setup_env
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
    post_setup
    start

    echo "DONE: installed all services"
    b2b domain
    ;;
install_single)
    install_single $1
    setup_env_single api
    ;;
install_packages)
    install_packages
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
post_setup)
    post_setup
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
*)
    source ../core/utils.sh
    if [ $is_option == true ]; then
        exit 1
    fi
    echo "   install    : setup code and start processes"
    echo "   install_single <name> : setup code and start single process"
    echo "   install_packages : install packages"
    echo "   init      : setup code for all services"
    echo "   init_single <name> : setup code for single service"
    echo "   setup_env  : setup env for all services"
    echo "   setup_env_single <name> : setup single env file"
    echo "   update_env : update cms, api .env file"
    echo "   update_env_single <name> : update single env file"
    echo "   start      : start processes"
    echo "   stop       : stop processes"
    echo "   clean_process : clean processes"
    echo "   clean      : clean processes and code"
    exit 1 # Command to come out of the program with status 1
    ;;
esac
