#!/usr/bin/env bash

set -euo pipefail

ECHO_PREFIX="[konsave-push]"

die() {
  echo "${ECHO_PREFIX} $1" >&2
  exit 1
}

# Navigate to fedora-kde directory.
REPO_ROOT="$(dirname "$(realpath "$0")")/.."
cd "$REPO_ROOT" || die "Failed to access repository root."

command -v git >/dev/null 2>&1 || die "git is not installed."
command -v konsave >/dev/null 2>&1 || die "konsave is not installed."

# Abort if working tree is dirty.
if [[ -n "$(git status --porcelain)" ]]; then
  die "There are uncommitted changes in the repository. Commit or stash them first."
fi

# Check whether local branch is in sync with upstream.
git fetch --quiet
UPSTREAM_REF="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

if [[ -z "$UPSTREAM_REF" ]]; then
  die "No upstream is configured for the current branch."
fi

LOCAL_COMMIT="$(git rev-parse @)"
UPSTREAM_COMMIT="$(git rev-parse '@{u}')"
BASE_COMMIT="$(git merge-base @ '@{u}')"

if [[ "$LOCAL_COMMIT" == "$UPSTREAM_COMMIT" ]]; then
  :
elif [[ "$LOCAL_COMMIT" == "$BASE_COMMIT" ]]; then
  die "Local branch is behind upstream. Run 'git pull --ff-only' first."
elif [[ "$UPSTREAM_COMMIT" == "$BASE_COMMIT" ]]; then
  die "Local branch is ahead of upstream. Push or reconcile before running this script."
else
  die "Local and upstream branches have diverged. Reconcile branches before running this script."
fi

# konsave: 
#   Remove config named "config". Ignore error if it doesn't exist.
#   Save the current config as "config".
konsave -r config 2>/dev/null || true
konsave -s config

# Navigate to konsave directory
# Remove config.knsv, if it exists.
# konsave: export current config named "config" to config.knsv.
cd konsave || die "Failed to access konsave directory."
rm -f config.knsv
konsave -e config

# Add updated config.knsv to git, commit and push.
cd "$REPO_ROOT" || die "Failed to return to repository root."
git add konsave/config.knsv

if git diff --cached --quiet; then
  echo "${ECHO_PREFIX} No changes in konsave/config.knsv; nothing to commit."
  exit 0
fi

read -r -p "${ECHO_PREFIX} Commit and push updated config.knsv? [y/n] (default: y): " CONFIRM
CONFIRM="${CONFIRM:-y}"

case "$CONFIRM" in
  y|Y)
      ;;
  n|N)
      echo "${ECHO_PREFIX} Operation cancelled by user."
      exit 0
      ;;
  *)
      die "Invalid response '$CONFIRM'. Expected y or n."
      ;;
esac

git commit -m "Update config.knsv"
git push
echo "${ECHO_PREFIX} Updated and pushed konsave/config.knsv successfully."