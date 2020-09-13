# conventional-pre-commits

Pre-commit hook scripts that enforce [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/), though you can configure them not to, and automatically update package version using npm.

Two scripts are used:

- `update_version.sh` checks the commit messages and updates project's version. It runs in `prepare-commit-msg` hook, which **cannot be skipped by the `--no-verify` option**. We use this hook because it is the only one that takes required parameters and runs for ordinary commits and merges (with conflicts or not).
- `after_version_update.sh` ammends the commit to update project's version in package.json and package-lock.json. It runs on `post-commit` or `post-merge` hooks depending on commit source.

## How to use

First, we will need to install Husky to run the scripts with git hooks.

`npm install husky --save dev`

Finally, we include the scripts in our package.json file:

``` json
"husky": {
  "hooks": {
    "prepare-commit-msg": "sh ./scripts/update_version.sh ${HUSKY_GIT_PARAMS}",
    "post-commit": "sh ./scripts/after_version_update.sh",
    "post-merge": "sh ./scripts/after_version_update.sh"
  }
}
```

And we are all set! You can now start conventionally committing.

## How does it work

`// TODO Explain default behavior`

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

`sh ./scripts/update_version.sh -p config ${HUSKY_GIT_PARAMS}`
