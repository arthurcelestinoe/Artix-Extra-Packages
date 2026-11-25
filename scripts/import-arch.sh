#!/usr/bin/env bash
# Traz o empacotamento de um pacote do Arch (PKGBUILD, patches e
# .nvchecker.toml) para packages/<inicial>/<pacote>, como ponto de partida.
# Os PKGBUILDs do Arch já baixam o código do upstream; o que normalmente falta
# para o Artix é tirar o systemd e escrever o pacote de init.
# Uso: scripts/import-arch.sh <pacote>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

pkg=${1:?uso: $0 <pacote>}
[[ $pkg =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ ]] || die "nome de pacote inválido: $pkg"
dest=$(pkg_dir "$pkg")
[[ ! -e $dest ]] || die "$dest já existe"

# O GitLab do Arch troca "+" por "plus" no nome do repositório.
url=https://gitlab.archlinux.org/archlinux/packaging/packages/${pkg//+/plus}.git

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth 1 "$url" "$tmp/repo" || die "não achei $pkg no Arch ($url)"

mkdir -p "$dest"
# O Arch licencia o empacotamento como 0BSD, a mesma licença deste repositório.
# Os arquivos de licença deles dão lugar ao LICENSE da raiz e ao cabeçalho SPDX.
tar -C "$tmp/repo" --exclude=./.git --exclude=./.SRCINFO \
    --exclude=./LICENSE --exclude=./LICENSES --exclude=./REUSE.toml -cf - . | tar -C "$dest" -xf -
# Guarda de qual commit do Arch partimos, para comparar depois.
git -C "$tmp/repo" rev-parse HEAD > "$dest/.arch-commit"

# Crédito aos autores do Arch. As linhas Maintainer/Contributor originais ficam.
if ! grep -q '^# SPDX-License-Identifier:' "$dest/PKGBUILD"; then
    sed -i '1i # SPDX-FileCopyrightText: Arch Linux contributors\n# SPDX-License-Identifier: 0BSD' "$dest/PKGBUILD"
elif ! grep -q '^# SPDX-FileCopyrightText: Arch Linux contributors' "$dest/PKGBUILD"; then
    sed -i '1i # SPDX-FileCopyrightText: Arch Linux contributors' "$dest/PKGBUILD"
fi

echo "importado em ${dest#"$ROOT"/} (Arch $(cut -c1-12 "$dest/.arch-commit"))"
[[ -f $dest/.nvchecker.toml ]] || warn "o Arch não tem .nvchecker.toml para $pkg; crie um (veja templates/package)"

echo
echo "Pontos para revisar (systemd):"
grep -rnEi --exclude=.arch-commit 'systemd|\.service|\.socket|\.timer' "$dest" || echo "  nenhum"
cat <<'EOF'

Lembretes:
  - Tire dependências de systemd/systemd-libs (no Artix, normalmente elogind/libelogind).
  - Arquivos .service/.socket/.timer não servem. Se for um serviço, crie um
    pacote de init separado, packages/<inicial>/<pacote>-<init> (veja templates/package-openrc).
  - sysusers.d e tmpfiles.d podem ficar: o Artix processa esses arquivos.
  - Acrescente a sua linha "# SPDX-FileCopyrightText: <ano> <nome> <email>" e
    "# Maintainer:" no topo do PKGBUILD, mantendo o crédito do Arch.
EOF
