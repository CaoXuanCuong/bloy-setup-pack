pull() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"

            if [ "$current_branch" == "master" ]; then
                git pull
                exit
            fi

            git fetch origin
            OUTPUT=$(git merge --no-commit --no-ff origin/master)
            
            if [ $? -eq 0 ]; then
                if [[ $OUTPUT == *"up to date"* ]]; then
                    echo -e "${Green}INFO: Already up to date.${Color_Off}"
                    exit
                fi
                git commit -m "Merge branch 'master' into $current_branch"
                echo -e "${Green}SUCCESS: Merge branch 'master' into $current_branch${Color_Off}"
            else
                git merge --abort
                echo -e "${Red}ERROR: Git pull failed, you need to pull and resolve conflicts manually${Color_Off}"
                error_list+=($DIRECTORY)
            fi
        )
    done
}

check_branch() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
            fi
        )
    done
}

commit() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
                # detect if there are uncommitted changes
                UNCOMMITTED=$(git status --porcelain)
                if [ -n "$UNCOMMITTED" ]; then
                    echo "${Yellow}INFO: You have uncommitted changes ${Color_Off}"
                    echo "$UNCOMMITTED" | awk '{print NR". "$0}'
                    echo "${Cyan}Enter commit message (leave blank to skip):${Color_Off}"
                    read message
                    if [ -n "$message" ]; then
                        git add .
                        git commit -m "$message"
                        echo "${Green}SUCCESS: Commit to branch ${current_branch^^} | Message: $message ${Color_Off}"
                    else 
                        echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                        exit
                    fi
                fi

            fi
        )
    done
}
    

push() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
                # detect if there are uncommitted changes
                UNCOMMITTED=$(git status --porcelain)
                if [ -n "$UNCOMMITTED" ]; then
                    echo "${Yellow}INFO: You have uncommitted changes ${Color_Off}"
                    echo "$UNCOMMITTED" | awk '{print NR". "$0}'
                    echo "${Cyan}Enter commit message (leave blank to skip):${Color_Off}"
                    read message
                    if [ -n "$message" ]; then
                        git add .
                        git commit -m "$message"
                        echo "${Green}SUCCESS: Commit to branch ${current_branch^^} | Message: $message ${Color_Off}"
                    else 
                        echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                        exit
                    fi
                fi

                git fetch origin
                commits=$(git log origin/$current_branch..$current_branch --oneline)
                if [ -n "$commits" ]; then
                    git push origin $current_branch
                    echo "${Green}SUCCESS: Push to branch ${current_branch^^} ${Color_Off}"
                    echo "$commits" | awk '{print NR". "$0}'
                else
                    echo "${Green}INFO: Remote branch already up to date. ${Color_Off}"
                fi
            fi
        )
    done
}

checkout() {

    print_usage() {
        echo "Usage: ./.sh checkout <branch name> <option>"
        echo "options:"
        echo "   -k | --skip   : stay on current branch if there are changes (default)"
        echo "   -c | --commit : commit changes to current branch before checkout"
        echo "   -s | --stash  : stash changes to current branch before checkout"
        echo "   -n | --new    : ask to create new branch if target branch is not exist"
        echo "   -h | --help   : show help"
        exit 1
    }

    if [ -z "$1" ]; then
        print_usage
    fi
    target_branch=$1
    shift

    action="skip"
    ask_new_branch=false

    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
        -k | --skip)
            action="skip"
            shift
            ;;
        -c | --commit)
            action="commit"
            shift
            ;;
        -s | --stash)
            action="stash"
            shift
            ;;
        -n | --new)
            ask_new_branch=true
            shift
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            echo "ERROR: Invalid option $key"
            print_usage
            exit 1
            ;;
        esac
    done

    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} checkout branch ${current_branch^^} --> ${target_branch^^} ----------${Color_Off}"
                
                if [ "$current_branch" == "$target_branch" ]; then
                    echo "${Cyan}INFO: Already on branch $target_branch ${Color_Off}"
                    exit
                fi

                # detect if there are uncommitted changes
                UNCOMMITTED=$(git status --porcelain)
                if [ -n "$UNCOMMITTED" ]; then
                    echo "${Yellow}INFO: You have uncommitted changes ${Color_Off}"
                    echo "${Red}$UNCOMMITTED${Color_Off}" | awk '{print $0}'
                    if [ -n "$action" ]; then
                        if [ "$action" == "commit" ]; then
                            echo "${Cyan}Enter commit message:${Color_Off}"
                            read message
                            if [ -n "$message" ]; then
                                git add .
                                git commit -m "$message"
                                echo "${Green}SUCCESS: Commit to branch ${current_branch^^} | Message: $message ${Color_Off}"
                            else 
                                echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                                exit
                            fi
                        elif [ "$action" == "stash" ]; then
                            git stash
                            echo "${Green}SUCCESS: Stash changes ${current_branch^^} ${Color_Off}"
                        elif [ "$action" == "skip" ]; then
                            echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                            exit
                        fi
                    fi
                fi

                git fetch origin
                git branch -r | grep -q $target_branch
                if [ $? -ne 0 ]; then
                    echo "${Red}WARNING: Branch $target_branch is not exist ${Color_Off}"
                    if [ "$ask_new_branch" == true ]; then
                        echo "${Cyan}Do you want to create new branch $target_branch? (y/n)${Color_Off}"
                        read answer
                        if [ "$answer" == "y" ]; then
                            git checkout -b $target_branch
                            echo "${Green}SUCCESS: Checkout $current_branch -> $target_branch ${Color_Off}"
                            exit
                        else
                            echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                            exit
                        fi
                    else
                        echo "${Yellow}INFO: Skipped ${DIRECTORY^^} ${Color_Off}"
                        exit
                    fi
                fi

                git checkout $target_branch
                echo "${Green}SUCCESS: Checkout $current_branch -> $target_branch ${Color_Off}"
            fi
        )
    done
}

show_domain() {
    if [ ! -f "domain_list_template" ]; then
        echo "ERROR: domain_list_template is not exist"
        exit 1
    fi

    while IFS=: read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^\s*# ]]; then
            continue
        fi
        # Extract record and port
        record=$(echo "$line" | awk -F':' '{print $1}')
        domain=$(echo $record | sed "s/<n>/$DEV_SITE/g" | sed "s/<zonename>/$CF_ZONE_NAME/g" | sed "s/^/https:\/\//g")
        echo $domain
    done < domain_list_template
}

update() {
    (pull)
    (install_packages)
    (update_db)
    (start)
}

upgrade() {
    print_usage() {
        echo "Usage: ./.sh upgrade <option>"
        echo "options:"
        echo "   -f | --force   : force upgrade"
        echo "   -h | --help   : show help"
        exit 1
    }

    force=false
    echo $0

    while [[ $# -gt 0 ]]; do
        key="$1"
        echo $key
        case $key in
        -f | --force)
            force=true
            shift
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            echo "ERROR: Invalid option $key"
            print_usage
            exit 1
            ;;
        esac
    done
    
    # migrate to use pnpm
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            
            if [ $force == true ] || [ ! -d "node_modules" ] || [ ! -f "pnpm-lock.yaml" ]; then
                echo "${Light_Blue}---------- Migrating to pnpm for ${DIRECTORY^^} ----------${Color_Off}"

                rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml

                pnpm install
            fi
        )
    done
    restart
}

set_remote_url() {
    setup_env
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
                git remote set-url origin $GIT_URL
                echo "${Green}SUCCESS: Set remote url to $GIT_URL ${Color_Off}"
            fi
        )
    done
}

is_option=true

case ${option} in
"pull")
    pull
    ;;
"commit")
    commit
    ;;
"push")
    push
    ;;
"checkout")
    checkout "$@"
    ;;
"branch")
    check_branch
    ;;
"domain")
    show_domain
    ;;
"update")
    update
    ;;
"upgrade")
    upgrade
    ;;
"set_remote_url")
    set_remote_url
    ;;
*)
    is_option=false
    echo "Usage: ./.sh <option>"
    echo "options:"
    echo "   pull        : pull changes from master branch"
    echo "   commit      : commit changes to current branch"
    echo "   push        : push changes to current branch"
    echo "   checkout    : checkout to branch"
    echo "   branch      : show current branch"
    echo "   domain      : show domain list"
    echo "   update      : pull, install packages, update db, restart"
    echo "   upgrade     : upgrade app"
    echo "   set_remote_url : set remote url"
    ;;
esac