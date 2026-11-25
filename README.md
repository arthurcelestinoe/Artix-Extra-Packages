# Artix Extra Packages

Repositório pacman que fornece pacotes compilados que não estão nos
repositórios oficiais do Artix Linux. Cada pacote é compilado a partir do
código-fonte do upstream, sem systemd. Os serviços têm pacotes de init
separados, para os inits suportados pelo Artix.

> [!WARNING]
> **Este repositório não é oficial e não tem nenhuma ligação com o projeto
> Artix Linux.** Ele foi feito para uso pessoal e é mantido por uma única
> pessoa.
>
> Se encontrar um bug em algum pacote daqui, reporte nas
> [issues deste repositório](https://github.com/arthurcelestinoe/Artix-Extra-Packages/issues),
> **e não nos canais oficiais do Artix** (fórum, bug tracker, IRC/Matrix).
> A equipe do Artix não dá suporte a estes pacotes.

> [!CAUTION]
> **Isenção de responsabilidade:** os pacotes são fornecidos "como estão", sem
> garantia de nenhum tipo, explícita ou implícita. Você os instala e usa por
> sua conta e risco. O mantenedor não se responsabiliza por perda de dados,
> sistemas quebrados ou qualquer outro dano decorrente do uso deste
> repositório.

## Usar o repositório

1. Importe e assine localmente a chave que assina os pacotes:

   ```bash
   curl -sL https://raw.githubusercontent.com/arthurcelestinoe/Artix-Extra-Packages/master/keys/artix-extra-unofficial.asc \
     | sudo pacman-key --add -
   sudo pacman-key --lsign-key BD87D7B0AADAA10656F9D04A8C8EF2FAA136031C
   ```

2. Adicione ao fim do `/etc/pacman.conf`:

   ```ini
   [artix-extra-unofficial]
   SigLevel = Required
   Server = https://github.com/arthurcelestinoe/Artix-Extra-Packages/releases/download/repo
   ```

3. `sudo pacman -Sy` e instale normalmente. Para serviços, instale também o
   pacote do seu init: `sudo pacman -S <pacote> <pacote>-openrc` (ou `-runit`,
   `-s6`, `-dinit`, quando houver).

## Como funciona

Os pacotes ficam agrupados pela inicial do nome, e os pacotes de init ficam
ao lado do programa:

```
packages/
├── f/
│   ├── foo/
│   │   ├── PKGBUILD          baixa a fonte direto do upstream
│   │   └── .nvchecker.toml   onde procurar versões novas
│   └── foo-openrc/           pacote de init (só para serviços)
│       ├── PKGBUILD
│       ├── foo.initd
│       └── foo.confd
└── 0/
    └── 0ad/                  nomes que começam com número também valem
templates/                    modelos para pacotes novos
```

Um pacote fora da pasta da sua inicial (por exemplo, `packages/b/foo`) faz o
CI falhar.

- **`update.yml`** roda todo dia. Ele consulta o upstream de cada pacote com
  [nvchecker](https://github.com/lilydjwg/nvchecker), que entende tags de
  qualquer repositório git, Releases do GitHub, GitLab, Gitea/Codeberg, PyPI,
  crates.io e outros. Para cada versão nova, ele atualiza `pkgver` e os
  checksums, testa a compilação e abre um PR.
- **`build.yml`** roda quando algo em `packages/` muda na `master`. Ele compila
  os pacotes alterados no container `artixlinux/artixlinux:base-devel`, assina
  com GPG e publica no Release `repo`, que é o repositório pacman. Versões
  antigas são apagadas do Release depois que as novas sobem.

## Adicionar um pacote

O jeito mais rápido é partir do empacotamento do Arch. Ele já usa a fonte do
upstream e quase sempre já tem um `.nvchecker.toml`:

```bash
scripts/import-arch.sh <pacote>
```

O script lista o que menciona systemd. Depois disso:

1. Troque dependências de `systemd`/`systemd-libs` por `elogind`/`libelogind`,
   quando houver.
2. Remova a instalação de `.service`/`.socket`/`.timer`.
3. Se for um serviço, crie o pacote de init seguindo as
   [convenções do Artix](#pacotes-de-init). Há um exemplo para OpenRC em
   [templates/package-openrc](templates/package-openrc).
4. Teste localmente no Artix: `scripts/build-package.sh <pacote>` (os pacotes
   saem em `out/`).
5. Confira o monitoramento: `scripts/check-updates.sh <pacote>`.

Para um pacote que não existe no Arch, copie `templates/package` para
`packages/<inicial>/<pacote>`.

## Contribuir

Contribuições são bem-vindas por pull request. Antes de propor um pacote, veja
se ele se encaixa nas regras abaixo.

### O que é aceito

- Software livre ou de código aberto, com licença aprovada pela
  [OSI](https://opensource.org/licenses) ou pela
  [FSF](https://www.gnu.org/licenses/license-list.html).
- Pacotes que **não** estão nos repositórios oficiais do Artix. Confira em
  [packages.artixlinux.org](https://packages.artixlinux.org) antes.
- Pacotes compilados a partir do código-fonte do upstream.

### O que não é aceito

- **Programas proprietários**, inclusive freeware, binários sem código-fonte e
  reempacotamentos de binários (`-bin`).
- **Programas de código aberto cuja política de marca registrada restringe
  builds de terceiros.** É o caso de projetos que não permitem distribuir uma
  versão compilada por outra pessoa, ou com patches, usando o nome e o logotipo
  oficiais, como o Firefox. O código é livre, mas o pacote acabaria exigindo
  rebranding ou autorização da dona da marca.
- Pacotes que dependem de systemd para funcionar.

### Pacotes de init

O repositório aceita scripts para qualquer init suportado pelo Artix: OpenRC,
runit, s6 e dinit. Se o programa é um serviço, **quem propõe o pacote deve
criar o pacote de init**, seguindo as convenções do Artix:

- **Um PKGBUILD próprio por init**, em `packages/<inicial>/<pacote>-<init>/`, separado do
  pacote principal. Não use pacote dividido (split package).
- `arch=(any)` e `pkgver` com a data da última mudança no script (`AAAAMMDD`),
  não a versão do programa.
- `provides=(init-<pacote>)` e `conflicts=(init-<pacote>)`, para que só um
  pacote de init do programa fique instalado por vez.
- Dependência do pacote principal e do init, com os arquivos nos caminhos que
  o Artix usa:

  | Pacote            | `depends`             | Arquivos instalados |
  |-------------------|-----------------------|---------------------|
  | `<pacote>-openrc` | `openrc`, `<pacote>`  | `/etc/init.d/<serviço>`, `/etc/conf.d/<serviço>` |
  | `<pacote>-runit`  | `runit`, `<pacote>`   | `/etc/runit/sv/<serviço>/run` |
  | `<pacote>-s6`     | `s6-base`, `<pacote>` | `/etc/s6/sv/<serviço>-srv/` e `/etc/s6/sv/<serviço>-log/` (definições s6-rc), `/etc/s6/config/<pacote>.conf` |
  | `<pacote>-dinit`  | `dinit`, `<pacote>`   | `/etc/dinit.d/<serviço>` |

- Na dúvida, use como referência um pacote de init do próprio Artix. O
  `openssh` tem os quatro: `openssh-openrc`, `openssh-runit`, `openssh-s6` e
  `openssh-dinit`, em [packages.artixlinux.org](https://packages.artixlinux.org)
  (com a lista de arquivos) e no
  [Gitea do Artix](https://gitea.artixlinux.org/packages/openssh-runit).

Basta enviar o init que você usa e consegue testar. Os outros podem vir em
contribuições futuras, de você ou de outra pessoa.

### Como enviar

1. Faça um fork e crie `packages/<inicial>/<pacote>/` com o `PKGBUILD` e o
   `.nvchecker.toml`, e, se for um serviço, `packages/<inicial>/<pacote>-<init>/`. O
   jeito mais fácil de começar é com `scripts/import-arch.sh` ou com os modelos
   `templates/package` e `templates/package-openrc`.
2. Compile num Artix atualizado com `scripts/build-package.sh <pacote>` e
   teste o programa e o serviço de verdade. Depois rode
   `scripts/lint-package.sh <pacote> out` para conferir as regras abaixo.
3. Confira se o monitoramento acha a versão atual:
   `scripts/check-updates.sh <pacote>`.
4. Abra o PR com um programa por vez (o pacote e os pacotes de init dele),
   informando:
   - a licença do programa;
   - qual init você testou;
   - qualquer patch aplicado e o motivo.

O PR é compilado e conferido automaticamente num container limpo do Artix.
Na primeira contribuição, o teste só roda depois que o mantenedor aprovar.

Checklist do `PKGBUILD`:

- `license=()` com o identificador SPDX correto.
- Fontes baixadas do upstream, com checksums (`updpkgsums` preenche). `SKIP`
  só para fontes git.
- Nenhuma dependência de `systemd`/`systemd-libs`.
- Nenhuma unit do systemd (`.service`, `.socket`, `.timer`) instalada.

## Limitações conhecidas

- Se o pacote que você quer propor depende de outro que ainda não está neste
  repositório, envie a dependência primeiro, num PR separado. O teste do PR só
  encontra dependências que já foram publicadas.
- Pacotes `-git`, que seguem commits em vez de versões, não são aceitos por
  enquanto: o monitoramento acompanha apenas tags e releases.
- Pacotes com epoch (`1:2.0-1`) são publicados com `.` no lugar de `:` no nome
  do arquivo, porque o GitHub não aceita `:` em arquivos de Release. Isso não
  afeta a instalação.
