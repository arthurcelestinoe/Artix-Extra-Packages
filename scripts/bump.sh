#!/usr/bin/env bash
# Atualiza o PKGBUILD para uma versão nova: pkgver, pkgrel=1 e checksums.
# Uso: scripts/bump.sh <pacote> <versão>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?uso: $0 <pacote> <versão>}
ver=${2:?uso: $0 <pacote> <versão>}
valid_pkg "$pkg" || die "pacote '$pkg' não encontrado"

# pkgver não aceita "-", ":" nem "/". Se o upstream usa esses caracteres,
# ajuste com from_pattern/to_pattern no .nvchecker.toml.
[[ $ver =~ ^[[:alnum:]._+]+$ ]] || die "'$ver' não é um pkgver válido"

pkgbuild=$(pkg_dir "$pkg")/PKGBUILD
sed -i -E "s/^pkgver=.*/pkgver=$ver/; s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
[[ $(pkgbuild_var "$pkgbuild" pkgver) == "$ver" ]] || die "não consegui alterar pkgver em $pkgbuild"

# updpkgsums baixa as fontes novas; roda numa cópia e trazemos só o PKGBUILD.
build=$(stage_package "$pkg")
(cd "$build" && as_builder updpkgsums)
cp "$build/PKGBUILD" "$pkgbuild"
rm -rf "$build"

echo "$pkg atualizado para $ver"
