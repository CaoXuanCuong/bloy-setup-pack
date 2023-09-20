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

check_branch() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Green}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
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
                echo -e "\n${Green}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
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
                echo -e "\n${Green}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
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

check_out() {
    if [ -z "$1" ]; then
        echo "Usage: ./.sh check_out <branch name>"
        exit 1
    fi

    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd $DIRECTORY
            if [ -d ".git" ]; then
                current_branch=$(git branch | grep \* | cut -d ' ' -f2)
                echo -e "\n${Green}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"
                
                if [ "$current_branch" == "$1" ]; then
                    echo "${Green}INFO: Already on branch $1 ${Color_Off}"
                    exit
                fi

                git fetch origin
                git branch -r | grep -q origin/$1
                if [ $? -ne 0 ]; then
                    echo "${Red}WARNING: Branch $1 is not exist ${Color_Off}"
                    echo "${Cyan}Do you want to create new branch $1 from $current_branch? (y/n)${Color_Off}" 
                    read -r answer
                    if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
                        git branch -m $1
                        echo "${Green}SUCCESS: Checkout to branch $1 ${Color_Off}"
                    fi
                    exit
                fi

                # detect if there are uncommitted changes
                UNCOMMITTED=$(git status --porcelain)
                if [ -n "$UNCOMMITTED" ]; then
                    echo "${Yellow}INFO: You have uncommitted changes ${Color_Off}"
                    echo "$UNCOMMITTED" | awk '{print NR". "$0}'
                    echo "${Cyan}Take action (commit, stash, or skip this branch) before checkout:${Color_Off}"
                    echo "  leave blank - skip this branch"
                    echo "  c - commit changes"
                    echo "  s - stash changes"
                    echo "  q - quit"
                    read action
                    if [ -n "$action" ]; then
                        if [ "$action" == "c" ]; then
                            echo "${Cyan}Enter commit message:${Color_Off}"
                            read message
                            if [ -n "$message" ]; then
                                git add .
                                git commit -m "$message"
                                echo "${Green}SUCCESS: Commit to branch ${current_branch^^} | Message: $message ${Color_Off}"
                            fi
                        elif [ "$action" == "s" ]; then
                            git stash
                            echo "${Green}SUCCESS: Stash changes ${Color_Off}"
                        elif [ "$action" == "q" ]; then
                            exit 1
                        fi
                    fi

                    
                fi


            fi
        )
    done
}

show_domain() {
    if [ ! -f "domain_list_template" ]; then
        echo "ERROR: domain_list_template is not exist"
        exit 1
    fi

    while IFS= read -r line; do
        unfomatted_domain=$(echo $line | cut -d':' -f1)
        domain=$(echo $unfomatted_domain | sed "s/<n>/$DEV_SITE/g" | sed "s/<zonename>/$CF_ZONE_NAME/g" | sed "s/^/https:\/\//g")
        echo $domain
    done < domain_list_template
}

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
    check_out $2
    ;;
"branch")
    check_branch
    ;;
"domain")
    show_domain
    ;;
*)
    echo "Usage: ./.sh <option>"
    echo "options:"
    echo "  pull        : pull changes from master branch"
    echo "  commit      : commit changes to current branch"
    echo "  push        : push changes to current branch"
    echo "  checkout    : checkout to branch"
    echo "  branch      : show current branch"
    echo "  domain      : show domain list"
    ;;
esac

exit 0