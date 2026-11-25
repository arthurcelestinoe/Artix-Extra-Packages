#!/usr/bin/env bash
# Checks the README rules on an already built package.
# Usage: scripts/lint-package.sh <package> <directory with the .pkg.tar.zst files>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?usage: $0 <package> <directory>}
out=${2:?usage: $0 <package> <directory>}
valid_pkg "$pkg" || die "package '$pkg' not found"
pkgbuild=$(pkg_dir "$pkg")/PKGBUILD

errors=0
fail() { printf 'error: %s: %s\n' "$pkg" "$*" >&2; errors=$((errors + 1)); }

# Reads a PKGBUILD array, one item per line.
array() {
    bash -c 'source "$1" >/dev/null 2>&1; declare -n a=$2; printf "%s\n" "${a[@]}"' _ "$pkgbuild" "$1"
}
has() { grep -qxF -- "$2" <<<"$1"; }

# SPDX header: declared authorship and license of the packaging file.
grep -q '^# SPDX-FileCopyrightText: .\+' "$pkgbuild" \
    || fail "PKGBUILD lacks '# SPDX-FileCopyrightText:' (see License and authorship in the README)"
grep -qx '# SPDX-License-Identifier: 0BSD' "$pkgbuild" \
    || fail "PKGBUILD lacks '# SPDX-License-Identifier: 0BSD'"
if grep -qE '^# SPDX-FileCopyrightText: .*(Your Name|Seu Nome)' "$pkgbuild"; then
    fail "PKGBUILD still has the template's placeholder authorship (Your Name)"
fi

# No systemd in the dependencies (with or without a version constraint).
# On Artix, systemd/systemd-libs/libsystemd are "provided" by
# artix-archlinux-support, a metadata-only package (no libraries) meant for
# using the Arch repositories. Depending on these names would force users to
# install that support, which is exactly what this repository avoids.
systemd_re='^(systemd|systemd-libs|libsystemd)([<>=].*)?$'
for var in depends makedepends; do
    if array "$var" | grep -qE "$systemd_re"; then
        fail "$var contains systemd/systemd-libs/libsystemd. Use libelogind (sd-login) or" \
             "libudev (sd-device), or disable systemd support in the build. These names" \
             "only exist on Artix through artix-archlinux-support, which is not an accepted dependency."
    fi
done

# Init packages follow the Artix conventions.
if [[ $pkg =~ ^(.+)-(openrc|runit|s6|dinit)$ ]]; then
    base=${BASH_REMATCH[1]}
    init=${BASH_REMATCH[2]}
    [[ $init == s6 ]] && initdep=s6-base || initdep=$init
    deps=$(array depends)
    has "$(array arch)" any               || fail "init package must have arch=(any)"
    has "$deps" "$initdep"                || fail "depends must include $initdep"
    has "$deps" "$base"                   || fail "depends must include $base"
    has "$(array provides)" "init-$base"  || fail "provides must include init-$base"
    has "$(array conflicts)" "init-$base" || fail "conflicts must include init-$base"
    [[ $(pkgbuild_var "$pkgbuild" pkgver) =~ ^[0-9]{8}$ ]] || fail "pkgver must be a YYYYMMDD date"
fi

# No systemd units inside the built packages.
shopt -s nullglob
built=("$out"/*.pkg.tar.zst)
(( ${#built[@]} )) || fail "no package in $out"
for f in "${built[@]}"; do
    units=$(bsdtar -tf "$f" | grep -E '^(usr/lib|etc)/systemd/.*\.(service|socket|timer|path|mount|target)$' || true)
    if [[ -n $units ]]; then
        fail "${f##*/} installs systemd units:"
        printf '  %s\n' $units >&2
    fi
done

(( errors == 0 )) || die "$errors problem(s) found"
echo "$pkg: ok"
