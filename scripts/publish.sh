#!/usr/bin/env bash
# Publishes packages to the pacman repository hosted in a GitHub Release.
# Runs on GitHub's ubuntu runner (needs gh, gpg and docker): the GPG key stays
# outside the container, and repo-add runs in an Artix image.
#
# Usage: scripts/publish.sh <directory with .pkg.tar.zst>
# Environment: GH_TOKEN, GH_REPO, GPG_PRIVATE_KEY, [GPG_PASSPHRASE],
#              [REPO_NAME=artix-extra-unofficial], [RELEASE_TAG=repo]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

in=${1:?usage: $0 <directory>}
tag=${RELEASE_TAG:-repo}
image=${ARTIX_IMAGE:-artixlinux/artixlinux:base-devel}
[[ -n ${GPG_PRIVATE_KEY:-} ]] || die "GPG_PRIVATE_KEY is not set: the repository must be signed"

shopt -s nullglob
new=("$in"/*.pkg.tar.zst)
(( ${#new[@]} )) || { echo "nothing to publish"; exit 0; }

work=$(mktemp -d)
stage=$work/stage
mkdir -p "$stage" "$work/db"

# Release assets can't contain ":" (epoch); GitHub would rename the file and
# pacman wouldn't find it. We rename before repo-add, which stores the file
# name in the database.
for f in "${new[@]}"; do
    b=${f##*/}
    cp "$f" "$stage/${b//:/.}"
done

if ! gh release view "$tag" >/dev/null 2>&1; then
    gh release create "$tag" --title "pacman repository" --latest=false \
        --notes "Packages and database of the [$REPO_NAME] repository. See the README for usage."
fi
gh release download "$tag" -D "$stage" -p "$REPO_NAME.db.tar.gz" -p "$REPO_NAME.files.tar.gz" 2>/dev/null \
    || echo "database does not exist yet; creating a new one"

# Finds the files of old versions, to delete them after the upload.
old=()
if [[ -f $stage/$REPO_NAME.db.tar.gz ]]; then
    tar -xzf "$stage/$REPO_NAME.db.tar.gz" -C "$work/db"
    for f in "$stage"/*.pkg.tar.zst; do
        b=${f##*/}
        name=${b%.pkg.tar.zst}
        name=${name%-*-*-*}               # strip version-release-architecture
        for entry in "$work"/db/*/; do
            e=$(basename "$entry")
            [[ ${e%-*-*} == "$name" ]] || continue
            o=$(awk '/^%FILENAME%$/ { getline; print; exit }' "$entry/desc")
            if [[ -n $o && $o != "$b" ]]; then old+=("$o"); fi
        done
    done
fi

docker run --rm -v "$stage:/repo" -w /repo "$image" \
    bash -c 'repo-add "$0.db.tar.gz" ./*.pkg.tar.zst' "$REPO_NAME"
sudo chown -R "$(id -u):$(id -g)" "$stage"

gpg --batch --import <<<"$GPG_PRIVATE_KEY"
sign() {
    gpg --batch --yes --pinentry-mode loopback --passphrase "${GPG_PASSPHRASE:-}" \
        --detach-sign --no-armor "$1"
}
for f in "$stage"/*.pkg.tar.zst "$stage/$REPO_NAME.db.tar.gz" "$stage/$REPO_NAME.files.tar.gz"; do
    sign "$f"
done

# pacman asks for <repo>.db and <repo>.files; repo-add creates symlinks, but
# Releases need real files.
for kind in db files; do
    rm -f "$stage/$REPO_NAME.$kind" "$stage/$REPO_NAME.$kind.sig"
    cp "$stage/$REPO_NAME.$kind.tar.gz" "$stage/$REPO_NAME.$kind"
    cp "$stage/$REPO_NAME.$kind.tar.gz.sig" "$stage/$REPO_NAME.$kind.sig"
done

# Order matters: packages first, database next, old files last. That way
# anyone syncing in the middle of the process doesn't get a 404.
gh release upload "$tag" --clobber "$stage"/*.pkg.tar.zst "$stage"/*.pkg.tar.zst.sig
gh release upload "$tag" --clobber "$stage/$REPO_NAME".{db,files}{,.sig} "$stage/$REPO_NAME".{db,files}.tar.gz{,.sig}
for o in "${old[@]}"; do
    gh release delete-asset "$tag" "$o" -y || warn "could not delete $o"
    gh release delete-asset "$tag" "$o.sig" -y || true
done

printf 'published: %s\n' "${new[@]##*/}"
