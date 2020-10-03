# conventional-pre-commits

Pre-commit hook scripts that enforce [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/), though you can configure them not to, and automatically update package version using Husky and npm.

Two scripts are used:

- `update_version.sh` checks the commit messages and updates project's version. It runs in `prepare-commit-msg` hook. We use this hook because it is the only one that takes required parameters and runs for ordinary commits and merges (with conflicts or not).
- `after_version_update.sh` amends the commit to update project's version in package.json and package-lock.json. It runs on `post-commit` or `post-merge` hooks depending on commit source.

The scripts can be skipped by setting an environment variable when committing, as `prepare-commit-msg` hook cannot be skipped by the `--no-verify` option:

`SKIP_PRE_COMMIT=true git commit -m 'feat: Add new feature'`

## Install

If you are installing this package via npm, run:

`npm install conventional-pre-commits --save-dev`

Otherwise, just make sure `after_version_update.sh` and `update_version.sh` are accessible from your project's root folder.

## How to use

First, we will need to install Husky to run the scripts with git hooks.

`npm install husky --save dev`

Finally, we include the scripts in our package.json file:

``` json
"husky": {
  "hooks": {
    "prepare-commit-msg": "bash node_modules/conventional-pre-commits/scripts/update_version.sh ${HUSKY_GIT_PARAMS}",
    "post-commit": "bash node_modules/conventional-pre-commits/scripts/after_version_update.sh",
    "post-merge": "bash node_modules/conventional-pre-commits/scripts/after_version_update.sh"
  }
}
```

And we are all set! You can now start conventionally committing.

## How does it work

These scripts will update your project's version when you make a commit. Conventional Commits format enforcing can be disabled but commits will need to follow it for the version to be updated. Different scenarios will trigger different version updates. See next section for script configuration.

Only commits made to enabled branches (develop, release and master by default) will trigger a version update.

### Single commits

If Conventional Commits format is being enforced, commit title format will first be checked and script will exit with an error if it fails.

If we are committing into a not update-enabled branch, version update will be skipped.

If commit message contains the string 'BREAKING CHANGE' (in its title or description), major version will be updated. This can be disabled via configuration.

``` txt
feat: Add very important feature

This is a BREAKING CHANGE.
```

If commit type is one of the minor version types, minor version will be updated.

`feat: Add new version`

If commit type is one of tha patch version types, patch version will be updated.

`fix: Fix bug`

Otherwise, an update version will not be triggered.

### Merges

Merges between the GitFlow main branches, which can be configured, will not trigger a version update.

`Merge branch 'develop' into 'release'`

If we are merging a fix branch (see configuration), patch version will be updated.

`Merge branch 'hotfix/production-bug`'

Otherwise, all commits in the source branch and not in the destination branch will be checked and version will be updated to the highest one the commit messages point out. For example, if we had two commits, `fix: Fix bug` and `feat: Add new feature`, minor version would be updated (for default options).

### Reverts

`Revert 'feat: Add new feature'`

Reverts do not trigger a version update. You could always run `npm version <version here> --no-git-tag-version` and then, after staging package.json and package-lock.json, run `SKIP_CONVENTIONAL_PRE_COMMIT=true git commit --amend --no-edit` to add the version update to the revert commit.

## Configuration

The script can be configured via a configuration file to adapt it to your git needs. The following options are provided:

- `main_branch`: Your repository's main branch. Merge commits to this branch will look like 'Merge branch 'release'' instead of like 'Merge branch 'develop' into 'release''.
- `branches`: A list of the branches you will want your project's version to be updated for when commits are made into them. For example, you may want to trigger a version update when committing to or merging into develop but not when committing into a feature branch, because that may provoke merge conflicts. However, if you want the version to be updated for all branches, you can set this option as `'.*'` (`branches='.*'`).
- `git_flow_from`: This option works hand in hand with `git_flow_to`. Merges from the branches listed here will not trigger a version update when merged into branches listed in `git_flow_to`. For example, if you are following [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow), you will not want your project's version to be updated when merging develop into release (or master). If you want to leave this list empty, just set this option to `''` (`git_flow_from=''`).
- `git_flow_to`: Explained above.
- `fix_branches`: A list of the branch types that will trigger a patch version update, no matter the messages of their commits. By default, branches named 'bugfix/...' or 'hotfix/...' will update patch version when merged into a branch included in `branches` option. If you want to leave this list empty, just set this option to `''`.
- `enforce_conventional_commits`: Whether to enforce Conventional Commits specification. Set it to `false` (`enforce_conventional_commits=false`) to skip this check and just leave it out of the configuration file otherwise.
- `commit_types`: List of valid commit types. This way you can override Conventional Commits specification with your own keywords. This list will be checked when enforcing commit formatting. If you do not want your commits' format to be checked just set previous option to `false`.
- `minor_version_types`: List of commit types that will trigger a minor version update. If you do not want any commit type to trigger a minor version update, set this option to `false`.
- `patch_version_types`: List of commit types that will trigger a patch version update. If you do not want any commit type to trigger a patch version update, set this option to `false`.
- `breaking_changes`: Whether to update major version when the commit message includes the string 'BREAKING CHANGE' (in its title or description). Set it to `false` to skip it and just leave it out of the configuration file otherwise.

These are the **default options** (and also an example of a valid configuration file, which does not need to have a file extension):

``` bash
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
```

With default options, only commits to branches named 'develop', 'release', or 'master' will trigger a version update. Merges from develop to release or from release to master will **not** trigger a version update.

To define the script's options, we have to add a `-p` option to the script followed by the relative path of the configuration file from the root folder of our repository (where package.json is located). Configuration file path, if provided, **must** be the first argument of the script. For example, if we had a configuration file named 'config':

`bash node_modules/conventional-pre-commits/scripts/update_version.sh -p config ${HUSKY_GIT_PARAMS}`

## Contributing

Do you need more customization or feel like something is missing or could be made better? Open an issue or a pull request!

As of now, revert commits do not trigger a version update because they will take the version previous to the reverted changes as the base for the update. If you have a good idea to fix this you know what to do!
