#!/usr/bin/env bash
# Imprime, em JSON, os pacotes a compilar: ["foo","foo-openrc"]
# Uso:
#   scripts/changed-packages.sh --all              todos os pacotes
#   scripts/changed-packages.sh --diff <base> <head>  alterados entre dois commits
#   scripts/changed-packages.sh <pacote>...         só os informados
# Nomes inválidos ou de pacotes removidos são ignorados. Falha se algum
# pacote estiver fora da pasta da sua inicial.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

misplaced=$(misplaced_packages)
if [[ -n $misplaced ]]; then
    printf 'erro: pacote fora da pasta da inicial (use packages/<inicial>/<pacote>):\n' >&2
    printf '  %s\n' $misplaced >&2
    exit 1
fi

case ${1:-} in
    --all)  candidates=$(list_packages) ;;
    --diff) candidates=$(git -C "$ROOT" diff --name-only "${2:?base}" "${3:?head}" -- packages/ | cut -d/ -f3 | sort -u) ;;
    *)      candidates="$*" ;;
esac

for p in $candidates; do
    if valid_pkg "$p"; then printf '%s\n' "$p"; else warn "ignorando: $p"; fi
done | jq -Rnc '[inputs | select(length > 0)]'
