#!/bin/bash
# "post-commit": "sh ./after_version_update.sh"
# "post-merge": "sh ./after_version_update.sh"

flag_file_path='./versionUpdated'

# If this file exists when entering the script, it means the version was updated
# in prepare-commit-message hook and we need to make a commit amend to add
# package.json and package-lock.json.
if [ -f $flag_file_path ]
then
  read -r merging_to_branch < $flag_file_path

  echo 'Amending commit to add package.json and package-lock.json...'
  
  if [[ $merging_to_branch =~ ^not_a_merge$ ]]
  then
    git add package.json package-lock.json
    git commit --amend --no-edit
  else
    # We are on a merge commit
    current_branch=`git branch --show-current`
    
    # Stash all changes before checking out branch we are merging into
    git add .
    git stash
    git checkout $merging_to_branch
    # Get only files we need from the stash
    git checkout stash@{0} -- package.json package-lock.json versionUpdated

    # Unstage versionUpdated and stage package.json and package-lock.json
    # before amending our commit
    git add package.json package-lock.json
    git reset versionUpdated
    git commit --amend --no-edit

    # Go back to the branch we were working with, pop the stash and reset/remove
    # files we previously checked out from the stash as they were not actually popped
    git checkout $current_branch
    git stash pop
    git reset package.json package-lock.json versionUpdated
    git restore package.json package-lock.json
    rm versionUpdated
  fi
fi

exit 0
