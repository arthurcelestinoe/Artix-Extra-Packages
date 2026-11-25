#!/usr/bin/env bash
# Prepares the artixlinux/artixlinux:base-devel container to build packages.
# Runs as root, in CI only.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

(( EUID == 0 )) || die "ci-setup.sh must run as root (inside the container)"

id builder &>/dev/null || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

# The workspace is mounted with a different owner; git complains without this.
git config --global --add safe.directory '*'

# If our repository already exists, enable it, for packages that depend on
# other packages from here. The database and packages are signed, so the
# public key from keys/ must be in pacman's keyring before syncing.
if [[ -n ${REPO_URL:-} ]] && curl -fsIL "$REPO_URL/$REPO_NAME.db" >/dev/null; then
    key=$ROOT/keys/$REPO_NAME.asc
    [[ -f $key ]] || die "public key not found: ${key#"$ROOT"/}"
    fpr=$(gpg --with-colons --show-keys "$key" | awk -F: '/^fpr/ { print $10; exit }')
    [[ -n $fpr ]] || die "could not read the fingerprint from ${key#"$ROOT"/}"
    pacman-key --add "$key"
    pacman-key --lsign-key "$fpr"

    cat >> /etc/pacman.conf <<EOF

[$REPO_NAME]
SigLevel = Required
Server = $REPO_URL
EOF
    pacman -Sy --noconfirm
    echo "repository [$REPO_NAME] enabled"
fi
