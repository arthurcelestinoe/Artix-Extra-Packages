#!/usr/bin/env bash
# Consulta o upstream de cada pacote com nvchecker e imprime, em JSON, os que
# têm versão nova: [{"pkg":"foo","version":"1.2.3"}, ...]
# Uso: scripts/check-updates.sh [pacote...]   (sem argumentos: todos)
#
# Cada pacote declara seu upstream em packages/<inicial>/<pacote>/.nvchecker.toml, no
# mesmo formato usado pelos repositórios de empacotamento do Arch.
# Defina GITHUB_TOKEN para evitar o limite de requisições da API do GitHub.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

command -v nvchecker >/dev/null || die "instale o nvchecker (pacman -S nvchecker)"
command -v jq >/dev/null || die "instale o jq"

if (( $# )); then pkgs=("$@"); else mapfile -t pkgs < <(list_packages); fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
conf=$work/nvchecker.toml
printf '[__config__]\noldver = "%s/old.json"\nnewver = "%s/new.json"\n\n' "$work" "$work" > "$conf"

declare -A current=()
for pkg in "${pkgs[@]}"; do
    valid_pkg "$pkg" || die "pacote '$pkg' não encontrado"
    cfg=$(pkg_dir "$pkg")/.nvchecker.toml
    # Pacotes de init não têm upstream: a versão é a data do script.
    if [[ ! -f $cfg && $pkg =~ -(openrc|runit|s6|dinit)$ ]]; then continue; fi
    if [[ ! -f $cfg ]]; then warn "$pkg: sem .nvchecker.toml, ignorado"; continue; fi
    grep -q "^\[\"\?$pkg\"\?\]" "$cfg" || die "$pkg: a seção do .nvchecker.toml deve se chamar [$pkg]"
    current[$pkg]=$(pkgbuild_var "$(pkg_dir "$pkg")/PKGBUILD" pkgver)
    cat "$cfg" >> "$conf"
    echo >> "$conf"
done

if (( ${#current[@]} == 0 )); then echo '[]'; exit 0; fi

for pkg in "${!current[@]}"; do
    jq -n --arg k "$pkg" --arg v "${current[$pkg]}" '{($k): {version: $v}}'
done | jq -s '{version: 2, data: add}' > "$work/old.json"

# Logs do nvchecker vão para stderr; stdout fica só com o resultado.
nvchecker -c "$conf" >&2

jq -r '.data | to_entries[] | "\(.key)\t\(.value.version)"' "$work/new.json" |
while IFS=$'\t' read -r pkg new; do
    old=${current[$pkg]:-}
    [[ -n $old && -n $new ]] || continue
    if (( $(vercmp "$new" "$old") > 0 )); then
        warn "$pkg: $old -> $new"
        jq -nc --arg pkg "$pkg" --arg version "$new" '{pkg: $pkg, version: $version}'
    fi
done | jq -sc .
