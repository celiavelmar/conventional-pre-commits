#!/bin/bash
# "prepare-commit-msg": "sh ./update_version.sh ${HUSKY_GIT_PARAMS}"

flag_file_path='./versionUpdated'
# If this file exists when entering the script, it means the version was already
# updated and we did a commit amend to update package.json and package-lock.json,
# so we must delete the file and exit the script.
if [ -f $flag_file_path ]
then
  echo 'Removing flag file...'
  rm $flag_file_path
  exit 0
fi

commit_message_file=$1
commit_source=$2

read -r commit_title < $commit_message_file
current_branch=`git branch --show-current`
merge_branch=''

createFlagFile() {
  # We create a flag file to know which branch we are merging into in
  # post-merge hook and because this hook will be run again after amend
  if [ $commit_source = 'merge' ]
  then
    # Print branch we are merging into to flag file
    echo $merge_branch > $flag_file_path
  else
    echo 'not_a_merge' > $flag_file_path
  fi
}

# Check if this is a merge commit
if [ $commit_source = 'merge' ]
then
  # Reverts have a 'merge' commit source
  if [[ $commit_title =~ ^Revert.+$ ]]
  then
    if [[ $current_branch =~ ^(develop|release|master)$ ]]
    then
      echo 'This is a revert. Updating minor version...'
      npm version minor --no-git-tag-version
      createFlagFile
    else
      echo 'Skipping version update for this branch...'
    fi
  else
    # Get branch we are merging into
    if [[ $commit_title =~ (into )([A-Za-z0-9-]+) ]]
    then
      merge_branch=${BASH_REMATCH[2]}
    else
      # Commit message will be something like "Merge branch 'release'"
      merge_branch='master'
    fi
    # Get branch we are actually merging from
    if [[ $commit_title =~ (Merge branch \')([A-Za-z0-9-/]+) ]]
    then
      current_branch=${BASH_REMATCH[2]}
    fi

    if [[ $commit_title =~ ^Merge[[:space:]]branch[[:space:]]\'(hotfix|bugfix)/.+$ ]]
    then
      echo 'This is a hotfix or bugfix branch merge. Updating patch version...'
      npm version patch --no-git-tag-version
      createFlagFile
    fi

    if [[ $current_branch =~ ^(develop|release)$ ]] && [[ $merge_branch =~ ^(release|master)$ ]]
    then
      echo 'Skipping version update for this merge...'
      exit 0
    fi
    if [[ ! $merge_branch =~ ^(develop|release|master)$ ]]
    then
      echo 'Skipping version update for this branch...'
      exit 0
    fi
    if [[ $commit_title =~ ^Merge[[:space:]]branch[[:space:]]\'.+\'[[:space:]]of.*$ ]] || [[ $commit_title =~ ^Merge[[:space:]]remote-traking.*$ ]]
    then
      echo 'You should have pulled before committing. Skipping version update...'
      exit 0
    fi

    version_to_update=''
    # Check all commits we are merging to find out which version we should update to
    git log --left-only --cherry-pick --pretty="%B" $current_branch...$merge_branch | {
      while read -r line
      do
        case $version_to_update in
          'major')
            break
          ;;
          'minor' | 'patch' | '')
            if [[ $line =~ ^.*BREAKING[[:space:]]CHANGE.*$ ]]
            then
              version_to_update='major'
            fi
          ;;
        esac
        case $version_to_update in
          'patch' | '')
            if [[ $line =~ ^feat(\(|:).*$ ]]
            then
              version_to_update='minor'
            fi
          ;;
        esac
        case $version_to_update in
          '')
            if [[ $line =~ ^fix(\(|:).*$ ]]
            then
              version_to_update='patch'
            fi
          ;;
        esac
      done

      # While loop runs in a sub-shell, so we need to do this inside the braces
      # or we will not have access to version_to_update value
      if [[ ! -z $version_to_update ]]
        then
          case $version_to_update in
            'major')
              npm version major --no-git-tag-version
            ;;
            'minor')
              npm version minor --no-git-tag-version
            ;;
            'patch')
              npm version patch --no-git-tag-version
            ;;
          esac
          createFlagFile
      fi
    }
  fi 
else
  # Match commit title to conventional commits commit message pattern
  if [[ $commit_title =~ ^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z[:space:]]+\))?:[[:space:]].+$ ]]
  then
    if [[ $current_branch =~ ^(develop|release|master)$ ]]
    then
      if grep -Fq 'BREAKING CHANGE' $commit_message_file
      then
        echo 'This is a BREAKING CHANGE. Updating major version...'
        npm version major --no-git-tag-version
        createFlagFile
      else
        if [[ $commit_title =~ ^(build|feat|revert).*$ ]]
        then
          echo 'This is a feature. Updating minor version...'
          npm version minor --no-git-tag-version
          createFlagFile
        elif [[ $commit_title =~ ^(chore|fix|perf|refactor).*$ ]]
        then
          echo 'This is a fix. Updating patch version...'
          npm version patch --no-git-tag-version
          createFlagFile
        else
          echo 'Skipping version update for this commit...'
        fi
      fi
    else
      echo 'Skipping version update for this branch...'
    fi
  else
    echo 'Commit title does not match Conventional Commits specification. Please, try again'
    exit 1
  fi
fi

exit 0
