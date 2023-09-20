pull() {
    for env_file in "${env_files[@]}"; do
        (
            cd $DESTINATION_FOLDER
            source $env_file
            cd "$DIRECTORY"
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} branch ${current_branch^^} ----------${Color_Off}"

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
                target_branch=$1
                echo -e "\n${Light_Blue}---------- ${DIRECTORY^^} checkout branch ${current_branch^^} --> ${target_branch^^} ----------${Color_Off}"
                
                if [ "$current_branch" == "$target_branch" ]; then
                    echo "${Cyan}INFO: Already on branch $target_branch ${Color_Off}"
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

                git fetch origin
                git branch -r | grep -q $target_branch
                if [ $? -ne 0 ]; then
                    echo "${Red}WARNING: Branch $target_branch is not exist ${Color_Off}"
                    echo "${Cyan}Do you want to create new branch $target_branch from $current_branch? (y/n)${Color_Off}" 
                    read -r answer
                    if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
                        git branch -m $1
                        echo "${Green}INFO: Created branch $target_branch ${Color_Off}"
                    fi
                    exit
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
    check_out $1
    ;;
"branch")
    check_branch
    ;;
"domain")
    show_domain
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
    ;;
esac