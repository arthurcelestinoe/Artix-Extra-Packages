#!/usr/bin/env bash
# Updates a PKGBUILD to a new version: pkgver, pkgrel=1 and checksums.
# Usage: scripts/bump.sh <package> <version>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?usage: $0 <package> <version>}
ver=${2:?usage: $0 <package> <version>}
valid_pkg "$pkg" || die "package '$pkg' not found"

# pkgver can't contain "-", ":" or "/". If upstream uses those characters,
# adjust with from_pattern/to_pattern in .nvchecker.toml.
[[ $ver =~ ^[[:alnum:]._+]+$ ]] || die "'$ver' is not a valid pkgver"

pkgbuild=$(pkg_dir "$pkg")/PKGBUILD
sed -i -E "s/^pkgver=.*/pkgver=$ver/; s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
[[ $(pkgbuild_var "$pkgbuild" pkgver) == "$ver" ]] || die "could not change pkgver in $pkgbuild"

# updpkgsums downloads the new sources; it runs on a copy and we bring back
# only the PKGBUILD.
build=$(stage_package "$pkg")
(cd "$build" && as_builder updpkgsums)
cp "$build/PKGBUILD" "$pkgbuild"
rm -rf "$build"

echo "$pkg updated to $ver"
