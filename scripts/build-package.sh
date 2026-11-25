#!/usr/bin/env bash
# Builds a package and copies the .pkg.tar.zst files to the output directory.
# Usage: scripts/build-package.sh <package> [output=out/]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?usage: $0 <package> [output directory]}
valid_pkg "$pkg" || die "package '$pkg' not found in packages/<initial>/"
out=$(realpath -m "${2:-$ROOT/out}")
mkdir -p "$out"

build=$(stage_package "$pkg")
as_builder mkdir -p "$build/_out"

(
    cd "$build"
    as_builder env \
        PKGDEST="$build/_out" \
        MAKEFLAGS="-j$(nproc)" \
        PACKAGER="${PACKAGER:-Artix Extra Packages CI}" \
        makepkg --syncdeps --noconfirm ${MAKEPKG_ARGS:-}
)

shopt -s nullglob
built=("$build"/_out/*.pkg.tar.*)
(( ${#built[@]} )) || die "makepkg did not produce any package"
cp "${built[@]}" "$out/"
printf 'built: %s\n' "${built[@]##*/}"
