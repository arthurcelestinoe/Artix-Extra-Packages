#!/usr/bin/env bash
# Confere as regras do README num pacote já compilado.
# Uso: scripts/lint-package.sh <pacote> <diretório com os .pkg.tar.zst>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?uso: $0 <pacote> <diretório>}
out=${2:?uso: $0 <pacote> <diretório>}
valid_pkg "$pkg" || die "pacote '$pkg' não encontrado"
pkgbuild=$(pkg_dir "$pkg")/PKGBUILD

errors=0
fail() { printf 'erro: %s: %s\n' "$pkg" "$*" >&2; errors=$((errors + 1)); }

# Lê um array do PKGBUILD, um item por linha.
array() {
    bash -c 'source "$1" >/dev/null 2>&1; declare -n a=$2; printf "%s\n" "${a[@]}"' _ "$pkgbuild" "$1"
}
has() { grep -qxF -- "$2" <<<"$1"; }

# Nada de systemd nas dependências (com ou sem restrição de versão).
# No Artix, quem "fornece" systemd/systemd-libs/libsystemd é o
# artix-archlinux-support, um pacote só de metadados (sem as bibliotecas) que
# serve para usar os repositórios do Arch. Depender desses nomes obrigaria o
# usuário a instalar esse suporte, que é justamente o que este repositório evita.
systemd_re='^(systemd|systemd-libs|libsystemd)([<>=].*)?$'
for var in depends makedepends; do
    if array "$var" | grep -qE "$systemd_re"; then
        fail "$var contém systemd/systemd-libs/libsystemd. Use libelogind (sd-login) ou" \
             "libudev (sd-device), ou desative o suporte a systemd no build. Esses nomes" \
             "só existem no Artix via artix-archlinux-support, que não é dependência aceita."
    fi
done

# Pacotes de init seguem as convenções do Artix.
if [[ $pkg =~ ^(.+)-(openrc|runit|s6|dinit)$ ]]; then
    base=${BASH_REMATCH[1]}
    init=${BASH_REMATCH[2]}
    [[ $init == s6 ]] && initdep=s6-base || initdep=$init
    deps=$(array depends)
    has "$(array arch)" any               || fail "pacote de init deve ter arch=(any)"
    has "$deps" "$initdep"                || fail "depends deve incluir $initdep"
    has "$deps" "$base"                   || fail "depends deve incluir $base"
    has "$(array provides)" "init-$base"  || fail "provides deve incluir init-$base"
    has "$(array conflicts)" "init-$base" || fail "conflicts deve incluir init-$base"
    [[ $(pkgbuild_var "$pkgbuild" pkgver) =~ ^[0-9]{8}$ ]] || fail "pkgver deve ser uma data AAAAMMDD"
fi

# Nenhuma unit do systemd dentro dos pacotes gerados.
shopt -s nullglob
built=("$out"/*.pkg.tar.zst)
(( ${#built[@]} )) || fail "nenhum pacote em $out"
for f in "${built[@]}"; do
    units=$(bsdtar -tf "$f" | grep -E '^(usr/lib|etc)/systemd/.*\.(service|socket|timer|path|mount|target)$' || true)
    if [[ -n $units ]]; then
        fail "${f##*/} instala units do systemd:"
        printf '  %s\n' $units >&2
    fi
done

(( errors == 0 )) || die "$errors problema(s) encontrado(s)"
echo "$pkg: ok"
