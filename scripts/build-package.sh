#!/usr/bin/env bash
# Compila um pacote e copia os .pkg.tar.zst para o diretório de saída.
# Uso: scripts/build-package.sh <pacote> [saída=out/]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?uso: $0 <pacote> [diretório de saída]}
valid_pkg "$pkg" || die "pacote '$pkg' não encontrado em packages/<inicial>/"
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
(( ${#built[@]} )) || die "makepkg não gerou nenhum pacote"
cp "${built[@]}" "$out/"
printf 'gerado: %s\n' "${built[@]##*/}"
