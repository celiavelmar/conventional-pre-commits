#!/bin/bash

# Default options
main_branch='master'
branches='develop|release|master'
git_flow_from='develop|release'
git_flow_to='release|master'
fix_branches='bugfix|hotfix'
enforce_conventional_commits=true
commit_types='build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test'
minor_version_types='build|feat|revert'
patch_version_types='chore|fix|perf|refactor'
breaking_changes=true

# Check if hook was skipped
if [ "$SKIP_CONVENTIONAL_PRE_COMMIT" = true ]
then
  echo 'Skipping conventional-pre-commit hook...'
  exit 0
fi

flag_file_path='./versionUpdated'
# If this file exists when entering the script, it means the version was already
# updated and we did a commit amend to update package.json and package-lock.json,
# so we must delete the file and exit the script.
if [ -f $flag_file_path ]
then
  rm $flag_file_path
  exit 0
fi

# Get user config from configuration file
user_config=false
while getopts ':p:' opt
do
  user_config=true
  config_file_path=$OPTARG
  source $config_file_path
done

# Read HUSKY_GIT_PARAMS
if [ $user_config = true ]
then
  commit_message_file=$3
  commit_source=$4
else
  commit_message_file=$1
  commit_source=$2
fi

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

updateVersion() {
  version=$1
  npm version $version --no-git-tag-version
  createFlagFile
}

# Check if this is a merge commit
if [ $commit_source = 'merge' ]
then
  # Reverts have a 'merge' commit source
  if [[ $commit_title =~ ^Revert.+$ ]]
  then
    echo 'Skipping version update for this commit...'
  else
    # Get branch we are merging into
    if [[ $commit_title =~ (into )([A-Za-z0-9-]+) ]]
    then
      merge_branch=${BASH_REMATCH[2]}
    else
      # Commit message will be something like "Merge branch 'release'"
      merge_branch=$main_branch
    fi
    # Get branch we are actually merging from
    if [[ $commit_title =~ (Merge branch \')([A-Za-z0-9-/]+) ]]
    then
      current_branch=${BASH_REMATCH[2]}
    fi

    # Skip version update for merges between main git flow branches
    # eval needed because we use a variable inside regex string
    if eval '[[ $current_branch =~ '"^($git_flow_from)$"' ]]' && eval '[[ $merge_branch =~ '"^($git_flow_to)$"' ]]'
    then
      echo 'Skipping version update for this merge...'
      exit 0
    fi
    # Skip version update for merges not into 
    if eval '[[ ! $merge_branch =~ '"^($branches)$"' ]]'
    then
      echo 'Skipping version update for this branch...'
      exit 0
    fi
    if [[ $commit_title =~ ^Merge[[:space:]]branch[[:space:]]\'.+\'[[:space:]]of.*$ ]] || [[ $commit_title =~ ^Merge[[:space:]]remote-traking.*$ ]]
    then
      echo 'You should have pulled before committing. Skipping version update...'
      exit 0
    fi

    # Update patch version for fix branches
    if eval '[[ $commit_title =~ '"^Merge[[:space:]]branch[[:space:]]\'($fix_branches)/.+$"' ]]'
    then
      updateVersion patch
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
            if [ ! $breaking_changes = false ] && [[ $line =~ ^.*BREAKING[[:space:]]CHANGE.*$ ]]
            then
              version_to_update='major'
            fi
          ;;
        esac
        case $version_to_update in
          'patch' | '')
            if eval '[[ $line =~ '"^($minor_version_types)(\(|:).*$"' ]]'
            then
              version_to_update='minor'
            fi
          ;;
        esac
        case $version_to_update in
          '')
            if eval '[[ $line =~ '"^($patch_version_types)(\(|:).*$"' ]]'
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
        updateVersion $version_to_update
      fi
    }
  fi 
else
  # Match commit title to conventional commits commit message pattern if enforced
  if [ $enforce_conventional_commits = false ] || eval '[[ $commit_title =~ '"^($commit_types)(\([a-z[:space:]]+\))?:[[:space:]].+$"' ]]'
  then
    if eval '[[ $current_branch =~ '"^($branches)$"' ]]'
    then
      if [ ! $breaking_changes = false ] && grep -Fq 'BREAKING CHANGE' $commit_message_file
      then
        updateVersion major
      else
        if [ ! $minor_version_types = false ] && eval '[[ $commit_title =~ '"^($minor_version_types)(\(|:).*$"' ]]'
        then
          updateVersion minor
        elif [ ! $patch_version_types = false ] && eval '[[ $commit_title =~ '"^($patch_version_types)(\(|:).*$"' ]]'
        then
          updateVersion patch
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
