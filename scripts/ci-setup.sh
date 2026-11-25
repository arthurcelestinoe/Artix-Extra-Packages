#!/usr/bin/env bash
# Prepara o container artixlinux/artixlinux:base-devel para compilar pacotes.
# Roda como root, só no CI.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

(( EUID == 0 )) || die "ci-setup.sh deve rodar como root (dentro do container)"

id builder &>/dev/null || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

# O workspace é montado com outro dono; o git reclama sem isso.
git config --global --add safe.directory '*'

# Se o nosso repositório já existe, habilita ele, para pacotes que dependem de
# outros pacotes daqui. No CI confiamos nos nossos próprios artefatos.
if [[ -n ${REPO_URL:-} ]] && curl -fsIL "$REPO_URL/$REPO_NAME.db" >/dev/null; then
    cat >> /etc/pacman.conf <<EOF

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = $REPO_URL
EOF
    pacman -Sy --noconfirm
    echo "repositório [$REPO_NAME] habilitado"
fi
