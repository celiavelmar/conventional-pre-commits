# conventional-pre-commits

Pre-commit hook scripts that enforce [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/) and automatically update package version using npm.

Two scripts are used:

- `update_version.sh` checks the commit messages and updates project's version. It runs in `prepare-commit-msg` hook, which **cannot be skipped by the `--no-verify` option**. We use this hook because it is the only one that takes required parameters and runs for ordinary commits and merges (with conflicts or not).
- `after_version_update.sh` ammends the commit to update project's version in package.json and package-lock.json. It runs on `post-commit` or `post-merge` hooks depending on commit source.

## How to use

First, we'll need to install Husky to run the scripts with git hooks.

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

`// TODO`
