# Helpers shared by the scripts. Use with: source "$(dirname "$0")/lib.sh"

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_NAME=${REPO_NAME:-artix-extra-unofficial}

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# makepkg refuses to run as root. In CI (container running as root) we use the
# "builder" user created by ci-setup.sh; locally it runs as yourself.
as_builder() {
    if (( EUID == 0 )); then
        sudo -u builder -- "$@"
    else
        "$@"
    fi
}

# Packages are grouped by their first letter: packages/<initial>/<package>/.
# E.g.: packages/f/foo, packages/f/foo-openrc, packages/0/0ad.
pkg_dir() {
    printf '%s/packages/%s/%s\n' "$ROOT" "${1:0:1}" "$1"
}

# A valid package has a name pacman accepts and a PKGBUILD in the right place.
valid_pkg() {
    [[ $1 =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ && -f $(pkg_dir "$1")/PKGBUILD ]]
}

list_packages() {
    local d n
    for d in "$ROOT"/packages/*/*/; do
        n=$(basename "$d")
        if valid_pkg "$n"; then printf '%s\n' "$n"; fi
    done
}

# Lists PKGBUILDs outside the folder of their initial (e.g. packages/b/foo).
misplaced_packages() {
    local f d n
    for f in "$ROOT"/packages/*/*/PKGBUILD; do
        d=${f%/PKGBUILD}
        n=$(basename "$d")
        [[ $d == "$(pkg_dir "$n")" ]] || printf '%s\n' "${d#"$ROOT"/}"
    done
}

# Copies the package to a temporary directory, so src/, pkg/ and downloaded
# sources don't pollute the repository. Prints the path of the copy.
stage_package() {
    local pkg=$1 dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/$pkg.XXXXXX")
    cp -a "$(pkg_dir "$pkg")/." "$dir/"
    if (( EUID == 0 )); then chown -R builder: "$dir"; fi
    printf '%s\n' "$dir"
}

# Reads a PKGBUILD variable (e.g. pkgver) in a subshell.
pkgbuild_var() {
    bash -c 'source "$1" >/dev/null 2>&1; printf "%s" "${!2}"' _ "$1" "$2"
}
