#!/usr/bin/env bash
# Queries each package's upstream with nvchecker and prints, as JSON, the ones
# with a new version: [{"pkg":"foo","version":"1.2.3"}, ...]
# Usage: scripts/check-updates.sh [package...]   (no arguments: all)
#
# Each package declares its upstream in packages/<initial>/<package>/.nvchecker.toml,
# in the same format used by Arch's packaging repositories.
# Set GITHUB_TOKEN to avoid the GitHub API rate limit.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

command -v nvchecker >/dev/null || die "install nvchecker (pacman -S nvchecker)"
command -v jq >/dev/null || die "install jq"

if (( $# )); then pkgs=("$@"); else mapfile -t pkgs < <(list_packages); fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
conf=$work/nvchecker.toml
printf '[__config__]\noldver = "%s/old.json"\nnewver = "%s/new.json"\n\n' "$work" "$work" > "$conf"

declare -A current=()
for pkg in "${pkgs[@]}"; do
    valid_pkg "$pkg" || die "package '$pkg' not found"
    cfg=$(pkg_dir "$pkg")/.nvchecker.toml
    # Init packages have no upstream: their version is the script's date.
    if [[ ! -f $cfg && $pkg =~ -(openrc|runit|s6|dinit)$ ]]; then continue; fi
    if [[ ! -f $cfg ]]; then warn "$pkg: no .nvchecker.toml, skipped"; continue; fi
    grep -q "^\[\"\?$pkg\"\?\]" "$cfg" || die "$pkg: the .nvchecker.toml section must be named [$pkg]"
    current[$pkg]=$(pkgbuild_var "$(pkg_dir "$pkg")/PKGBUILD" pkgver)
    cat "$cfg" >> "$conf"
    echo >> "$conf"
done

if (( ${#current[@]} == 0 )); then echo '[]'; exit 0; fi

for pkg in "${!current[@]}"; do
    jq -n --arg k "$pkg" --arg v "${current[$pkg]}" '{($k): {version: $v}}'
done | jq -s '{version: 2, data: add}' > "$work/old.json"

# nvchecker logs go to stderr; stdout carries only the result.
nvchecker -c "$conf" >&2

jq -r '.data | to_entries[] | "\(.key)\t\(.value.version)"' "$work/new.json" |
while IFS=$'\t' read -r pkg new; do
    old=${current[$pkg]:-}
    [[ -n $old && -n $new ]] || continue
    if (( $(vercmp "$new" "$old") > 0 )); then
        warn "$pkg: $old -> $new"
        jq -nc --arg pkg "$pkg" --arg version "$new" '{pkg: $pkg, version: $version}'
    fi
done | jq -sc .
