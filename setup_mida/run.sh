#!/bin/bash
option="${1}"
shift 1

app_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -L "$0" ]; then
  script=$(readlink -f "$0")
  app_script_dir=$(dirname "$script")
fi
cd $app_script_dir

source $HOME/.nvm/nvm.sh

while getopts ":p" opt; do
  case $opt in
    p)
      echo "${Green}******** Enter app environment. ********${Color_Off}"
      read -p "SHOPIFY_API_KEY: " SHOPIFY_API_KEY

      read -p "SHOPIFY_API_SECRET_KEY: " SHOPIFY_API_SECRET_KEY
      
      read -p "API_VERSION (Default: 2022-10): " API_VERSION
      API_VERSION=${API_VERSION:-2022-10}
      
      cp app.env.example app.env
      sed -i "s/<SHOPIFY_API_KEY>/$SHOPIFY_API_KEY/g" app.env
      sed -i "s/<SHOPIFY_API_SECRET_KEY>/$SHOPIFY_API_SECRET_KEY/g" app.env
      sed -i "s/<API_VERSION>/$API_VERSION/g" app.env
      ;;
    *)
      echo "${Red}******** Invalid option: -$OPTARG ********${Color_Off}" >&2
      exit 1
    ;;
  esac
done

if [ ! -f "app.env" ]; then
    echo "ERROR: app.env file is not exist"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    echo "ERROR: npm is not installed"
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
    sed -i "s/<CF_ZONE_NAME>/$CF_ZONE_NAME/g" $1.env
    sed -i "s/<n>/$DEV_SITE/g" $1.env
    sed -i "s/<API_VERSION>/$API_VERSION/g" $1.env
    sed -i "s/<SHOPIFY_API_KEY>/$SHOPIFY_API_KEY/g" $1.env
    sed -i "s/<SHOPIFY_API_SECRET_KEY>/$SHOPIFY_API_SECRET_KEY/g" $1.env
    
    sed -i "s/<CMS_PORT>/$CMS_PORT/g" $1.env
    sed -i "s/<API_PORT>/$API_PORT/g" $1.env
    sed -i "s/<HM_PORT>/$HM_PORT/g" $1.env
    sed -i "s/<RECORDER_PORT>/$RECORDER_PORT/g" $1.env

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
            echo "install code and packages in $DIRECTORY"
            git clone "$BITBUCKET_URL" .
            if [ -f "package.json" ]; then
                npm install
            fi
            if [ -f "requirements.txt" ]; then
                python3.8 -m venv venv
                python3 -m pip install -r requirements.txt
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
    echo "init code for $DIRECTORY"
    cd $DIRECTORY 
    git clone $BITBUCKET_URL $DESTINATION_FOLDER/$DIRECTORY
    if [ -f "package.json" ]; then
        npm install
    fi
    if [ -f "requirements.txt" ]; then
        python3.8 -m venv venv
        python3 -m pip install -r requirements.txt
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

setup_python_environment() {
    sudo nala update
    sudo nala install software-properties-common -y
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo nala update
    sudo nala install python3.8 -y
    sudo nala install python3.8-venv -y
    sudo nala install python3-pip -y
}

install_dependencies() {
    if command -v mongod &>/dev/null; then
        echo "${Red} ******** Disable mongodb service ********${Color_Off}"
        systemctl stop mongod
        systemctl disable mongod
    fi

    if command -v rabbitmq-server &>/dev/null; then
        echo "${Red} ******** Disable rabbitmq service ********${Color_Off}"
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
            pm2 describe $PROCESS_NAME > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "# pm2 restart $PROCESS_NAME"
                pm2 restart $PROCESS_NAME --update-env
            else
                if [ -f "package.json" ]; then
                    echo "# pm2 start npm --name $PROCESS_NAME -- run dev"
                    pm2 start npm --name $PROCESS_NAME -- run dev
                fi
                if [ -f "run.py" ]; then
                    echo "# pm2 start run.py --name $PROCESS_NAME --interpreter python3"
                    pm2 start run.py --name $PROCESS_NAME --interpreter python3
                fi
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
        fi

        if [ -f "run.py" ]; then
            echo "# pm2 start run.py --name $PROCESS_NAME --interpreter python3"
            pm2 start run.py --name $PROCESS_NAME --interpreter python3
        fi
        pm2 save
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

    if [ "$(docker ps -q -f name=mongodb)" != "" ]; then
        docker-compose -f ../tools/mongodb/docker-compose.yml down
        echo "INFO: stop mongodb container"
    fi

    if [ "$(docker ps -q -f name=rabbitmq)" != "" ]; then
        docker-compose -f ../tools/rabbitmq/docker-compose.yml down
        echo "INFO: stop rabbitmq container"
    fi
}

pull() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            echo -e "\033[32m\n----------- ${DIRECTORY^^} branch: ${GIT_BRANCH^^}------------\033[0m"

            git fetch origin
            OUTPUT=$(git merge --no-commit --no-ff origin/master)
            
            if [ $? -eq 0 ]; then
                if [[ $OUTPUT == *"up to date"* ]]; then
                    echo -e "\033[32mINFO: Already up to date.\033[0m"
                    exit
                fi
                git commit -m "Merge branch 'master' into $GIT_BRANCH"
                echo -e "\033[32mSUCCESS: Merge branch 'master' into $GIT_BRANCH\033[0m"
            else
                git merge --abort
                echo -e "\033[31mERROR: Git pull failed, you need to pull and resolve conflicts manually\033[0m"
            fi
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

install_packages() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            if [ -f "package.json" ]; then
                echo "# npm install"
                npm install
            fi
            if [ -f "requirements.txt" ]; then
                echo "# pip install -r requirements.txt"
                pip install -r requirements.txt
            fi
        )
    done
}

case ${option} in
install_dependencies)
    install_dependencies
    setup_python_environment
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
    setup_python_environment
    init_code
    setup_env
    post_setup
    start
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
pull)
    pull
    ;;
*)
    echo "./.sh <option>"
    echo "option:"
    echo "   install    : setup code and start processes"
    echo "   install_single <name> : setup code and start single process"
    echo "   install_packages : install packages"
    echo "   init      : setup code for all services"
    echo "   init_single <name> : setup code for single service"
    echo "   clean      : delete all code cms,api,proxy,...."
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
