#!/usr/bin/env bash
# Publica pacotes no repositório pacman hospedado num GitHub Release.
# Roda no runner ubuntu do GitHub (precisa de gh, gpg e docker): a chave GPG
# fica fora do container, e o repo-add roda numa imagem do Artix.
#
# Uso: scripts/publish.sh <diretório com .pkg.tar.zst>
# Ambiente: GH_TOKEN, GH_REPO, GPG_PRIVATE_KEY, [GPG_PASSPHRASE],
#           [REPO_NAME=artix-extra-unofficial], [RELEASE_TAG=repo]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

in=${1:?uso: $0 <diretório>}
tag=${RELEASE_TAG:-repo}
image=${ARTIX_IMAGE:-artixlinux/artixlinux:base-devel}
[[ -n ${GPG_PRIVATE_KEY:-} ]] || die "GPG_PRIVATE_KEY não definido: o repositório precisa ser assinado"

shopt -s nullglob
new=("$in"/*.pkg.tar.zst)
(( ${#new[@]} )) || { echo "nada para publicar"; exit 0; }

work=$(mktemp -d)
stage=$work/stage
mkdir -p "$stage" "$work/db"

# Assets de Release não podem ter ":" (epoch); o GitHub trocaria o nome e o
# pacman não acharia o arquivo. Renomeamos antes do repo-add, que grava o
# nome do arquivo no banco.
for f in "${new[@]}"; do
    b=${f##*/}
    cp "$f" "$stage/${b//:/.}"
done

if ! gh release view "$tag" >/dev/null 2>&1; then
    gh release create "$tag" --title "Repositório pacman" --latest=false \
        --notes "Pacotes e banco do repositório [$REPO_NAME]. Veja o README para usar."
fi
gh release download "$tag" -D "$stage" -p "$REPO_NAME.db.tar.gz" -p "$REPO_NAME.files.tar.gz" 2>/dev/null \
    || echo "banco ainda não existe; criando um novo"

# Descobre os arquivos das versões antigas, para apagar depois do upload.
old=()
if [[ -f $stage/$REPO_NAME.db.tar.gz ]]; then
    tar -xzf "$stage/$REPO_NAME.db.tar.gz" -C "$work/db"
    for f in "$stage"/*.pkg.tar.zst; do
        b=${f##*/}
        name=${b%.pkg.tar.zst}
        name=${name%-*-*-*}               # tira versão-release-arquitetura
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

# O pacman pede <repo>.db e <repo>.files; o repo-add cria symlinks, mas
# Releases precisam de arquivos de verdade.
for kind in db files; do
    rm -f "$stage/$REPO_NAME.$kind" "$stage/$REPO_NAME.$kind.sig"
    cp "$stage/$REPO_NAME.$kind.tar.gz" "$stage/$REPO_NAME.$kind"
    cp "$stage/$REPO_NAME.$kind.tar.gz.sig" "$stage/$REPO_NAME.$kind.sig"
done

# Ordem importa: pacotes primeiro, banco depois, antigos por último. Assim
# quem sincronizar no meio do processo não recebe um 404.
gh release upload "$tag" --clobber "$stage"/*.pkg.tar.zst "$stage"/*.pkg.tar.zst.sig
gh release upload "$tag" --clobber "$stage/$REPO_NAME".{db,files}{,.sig} "$stage/$REPO_NAME".{db,files}.tar.gz{,.sig}
for o in "${old[@]}"; do
    gh release delete-asset "$tag" "$o" -y || warn "não consegui apagar $o"
    gh release delete-asset "$tag" "$o.sig" -y || true
done

printf 'publicado: %s\n' "${new[@]##*/}"
