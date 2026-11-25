#!/usr/bin/env bash
# Prints, as JSON, the packages to build: ["foo","foo-openrc"]
# Usage:
#   scripts/changed-packages.sh --all                 all packages
#   scripts/changed-packages.sh --diff <base> <head>  changed between two commits
#   scripts/changed-packages.sh <package>...          only the given ones
# Invalid names and removed packages are ignored. Fails if any package is
# outside the folder of its initial.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

misplaced=$(misplaced_packages)
if [[ -n $misplaced ]]; then
    printf 'error: package outside the folder of its initial (use packages/<initial>/<package>):\n' >&2
    printf '  %s\n' $misplaced >&2
    exit 1
fi

case ${1:-} in
    --all)  candidates=$(list_packages) ;;
    --diff) candidates=$(git -C "$ROOT" diff --name-only "${2:?base}" "${3:?head}" -- packages/ | cut -d/ -f3 | sort -u) ;;
    *)      candidates="$*" ;;
esac

for p in $candidates; do
    if valid_pkg "$p"; then printf '%s\n' "$p"; else warn "ignoring: $p"; fi
done | jq -Rnc '[inputs | select(length > 0)]'
