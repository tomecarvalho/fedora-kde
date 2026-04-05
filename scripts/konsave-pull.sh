#!/usr/bin/env bash

set -euo pipefail

ECHO_PREFIX="[konsave-pull]"

die() {
	echo "${ECHO_PREFIX} $1" >&2
	exit 1
}

# Navigate to fedora-kde directory.
REPO_ROOT="$(dirname "$(realpath "$0")")/.."
cd "$REPO_ROOT" || die "Failed to access repository root."

command -v git >/dev/null 2>&1 || die "git is not installed."
command -v konsave >/dev/null 2>&1 || die "konsave is not installed."

# Check whether local branch needs a pull from upstream.
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
	echo "${ECHO_PREFIX} Local branch is ahead of upstream; continuing (no pull needed)."
else
	die "Local and upstream branches have diverged. Reconcile branches before running this script."
fi

CONFIG_FILE="konsave/config.knsv"
[[ -f "$CONFIG_FILE" ]] || die "Missing ${CONFIG_FILE}."

# Remove existing config if present, then import and apply tracked config.
konsave -r config 2>/dev/null || true
konsave -i "$CONFIG_FILE"
konsave -a config

echo "${ECHO_PREFIX} Imported and applied ${CONFIG_FILE} successfully."
