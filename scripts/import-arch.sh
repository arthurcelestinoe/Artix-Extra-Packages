#!/usr/bin/env bash
# Brings a package's Arch packaging (PKGBUILD, patches and .nvchecker.toml)
# into packages/<initial>/<package>, as a starting point.
# Arch PKGBUILDs already download the upstream source; what Artix usually
# still needs is removing systemd and writing the init package.
# Usage: scripts/import-arch.sh <package>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?usage: $0 <package>}
[[ $pkg =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ ]] || die "invalid package name: $pkg"
dest=$(pkg_dir "$pkg")
[[ ! -e $dest ]] || die "$dest already exists"

# Arch's GitLab replaces "+" with "plus" in repository names.
url=https://gitlab.archlinux.org/archlinux/packaging/packages/${pkg//+/plus}.git

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth 1 "$url" "$tmp/repo" || die "could not find $pkg on Arch ($url)"

mkdir -p "$dest"
# Arch licenses its packaging as 0BSD, the same license as this repository.
# Their license files give way to the root LICENSE and the SPDX header.
tar -C "$tmp/repo" --exclude=./.git --exclude=./.SRCINFO \
    --exclude=./LICENSE --exclude=./LICENSES --exclude=./REUSE.toml -cf - . | tar -C "$dest" -xf -
# Records which Arch commit we started from, to compare later.
git -C "$tmp/repo" rev-parse HEAD > "$dest/.arch-commit"

# Credit to the Arch authors. The original Maintainer/Contributor lines stay.
if ! grep -q '^# SPDX-License-Identifier:' "$dest/PKGBUILD"; then
    sed -i '1i # SPDX-FileCopyrightText: Arch Linux contributors\n# SPDX-License-Identifier: 0BSD' "$dest/PKGBUILD"
elif ! grep -q '^# SPDX-FileCopyrightText: Arch Linux contributors' "$dest/PKGBUILD"; then
    sed -i '1i # SPDX-FileCopyrightText: Arch Linux contributors' "$dest/PKGBUILD"
fi

echo "imported into ${dest#"$ROOT"/} (Arch $(cut -c1-12 "$dest/.arch-commit"))"
[[ -f $dest/.nvchecker.toml ]] || warn "Arch has no .nvchecker.toml for $pkg; create one (see templates/package)"

echo
echo "Things to review (systemd):"
grep -rnEi --exclude=.arch-commit 'systemd|\.service|\.socket|\.timer' "$dest" || echo "  none"
cat <<'EOF'

Reminders:
  - Remove systemd/systemd-libs dependencies (on Artix, usually elogind/libelogind).
  - .service/.socket/.timer files are useless here. If it is a service, create a
    separate init package, packages/<initial>/<package>-<init> (see templates/package-openrc).
  - sysusers.d and tmpfiles.d files can stay: Artix processes them.
  - Add your own "# SPDX-FileCopyrightText: <year> <name> <email>" and
    "# Maintainer:" lines at the top of the PKGBUILD, keeping the Arch credit.
EOF
