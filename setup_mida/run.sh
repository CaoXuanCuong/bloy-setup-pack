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
                yarn install
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
        yarn install
    fi
    if [ -f "requirements.txt" ]; then
        python3.8 -m venv venv
        python3 -m pip install -r requirements.txt
    fi
}

post_setup() {
    return
}

setup_python_environment() {
    sudo apt update
    sudo apt install software-properties-common
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install python3.8 -y
    sudo apt install python3.8-venv -y
}

install_dependencies() {
    # check if rabbitmq-server and mongosh are installed
    if ! command -v rabbitmq-server &> /dev/null
    then
        echo "Do you want to install rabbitmq-server locally? (y/n)"
        read answer

        if [ "$answer" != "${answer#[Yy]}" ] ;then
            echo "INFO: installing rabbitmq-server..."
            sudo apt update
            sudo apt install gnupg2 software-properties-common apt-transport-https lsb-release -y 
            curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | sudo -E bash
            sudo apt update
            sudo apt install erlang -y
            curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.deb.sh | sudo bash
            sudo apt update
            sudo apt install rabbitmq-server -y
            sudo systemctl enable rabbitmq-server
            sudo rabbitmq-plugins enable rabbitmq_management
            sudo rabbitmqctl add_user $RABBITMQ_USER $RABBITMQ_PASSWORD
            sudo rabbitmqctl set_user_tags $RABBITMQ_USER administrator
            sudo rabbitmqctl set_permissions -p / $RABBITMQ_USER ".*" ".*" ".*"
        fi
    fi
    
    if ! command -v mongosh &> /dev/null
    then
        echo "Do you want to install mongosh locally? (y/n)"
        read answer

        if [ "$answer" != "${answer#[Yy]}" ] ;then
            echo "INFO: installing mongosh..."
            echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
            sudo apt update
            sudo apt install -y mongodb-org
            mongosh $MONGO_DB --eval "db.createUser({user: '$MONGO_USER', pwd: '$MONGO_PASSWORD', roles: [{role: 'dbOwner', db: '$MONGO_DB'}]})"
            sudo sed -i "s/port:.*/port: $MONGO_PORT/" /etc/mongod.conf
            sudo systemctl restart mongod
        fi
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
    if [ -z "$2" ]; then
        echo "Usage: ./.sh init_single <name>"
        exit 1
    fi
    init_code_single $2
    setup_env_single $2
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
    install_single $2
    setup_env_single api
    ;;
restart)
    start
    ;;
restart_single)
    if [ -z "$2" ]; then
        echo "Usage: ./.sh restart_single <name>"
        exit 1
    fi
    start_single $2
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
