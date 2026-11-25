# Funções compartilhadas pelos scripts. Use com: source "$(dirname "$0")/lib.sh"

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_NAME=${REPO_NAME:-artix-extra-unofficial}

die()  { printf 'erro: %s\n' "$*" >&2; exit 1; }
warn() { printf 'aviso: %s\n' "$*" >&2; }

# O makepkg se recusa a rodar como root. No CI (container como root) usamos o
# usuário "builder" criado por ci-setup.sh; localmente roda como você mesmo.
as_builder() {
    if (( EUID == 0 )); then
        sudo -u builder -- "$@"
    else
        "$@"
    fi
}

# Os pacotes ficam agrupados pela inicial: packages/<inicial>/<pacote>/.
# Ex.: packages/f/foo, packages/f/foo-openrc, packages/0/0ad.
pkg_dir() {
    printf '%s/packages/%s/%s\n' "$ROOT" "${1:0:1}" "$1"
}

# Um pacote válido tem nome permitido pelo pacman e um PKGBUILD no lugar certo.
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

# Lista PKGBUILDs fora da pasta da inicial certa (ex.: packages/b/foo).
misplaced_packages() {
    local f d n
    for f in "$ROOT"/packages/*/*/PKGBUILD; do
        d=${f%/PKGBUILD}
        n=$(basename "$d")
        [[ $d == "$(pkg_dir "$n")" ]] || printf '%s\n' "${d#"$ROOT"/}"
    done
}

# Copia o pacote para um diretório temporário, para não sujar o repositório
# com src/, pkg/ e fontes baixadas. Imprime o caminho da cópia.
stage_package() {
    local pkg=$1 dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/$pkg.XXXXXX")
    cp -a "$(pkg_dir "$pkg")/." "$dir/"
    if (( EUID == 0 )); then chown -R builder: "$dir"; fi
    printf '%s\n' "$dir"
}

# Lê uma variável do PKGBUILD (ex.: pkgver) num subshell.
pkgbuild_var() {
    bash -c 'source "$1" >/dev/null 2>&1; printf "%s" "${!2}"' _ "$1" "$2"
}
