# Artix Extra Packages

**English** | [Português (Brasil)](README.pt-BR.md)

A pacman repository providing compiled packages that are not in the official
Artix Linux repositories. Every package is built from the upstream source
code, without systemd. Services have separate init packages for the init
systems Artix supports.

> [!WARNING]
> **This repository is unofficial and has no affiliation with the Artix Linux
> project.** It was made for personal use and is maintained by a single
> person.
>
> If you find a bug in a package from here, report it in
> [this repository's issues](https://github.com/arthurcelestinoe/Artix-Extra-Packages/issues),
> **not in the official Artix channels** (forum, bug tracker, IRC/Matrix).
> The Artix team does not support these packages.

> [!CAUTION]
> **Disclaimer:** the packages are provided "as is", without warranty of any
> kind, express or implied. You install and use them at your own risk. The
> maintainer is not responsible for data loss, broken systems or any other
> damage resulting from the use of this repository.

## Using the repository

1. Import and locally sign the key that signs the packages:

   ```bash
   curl -sL https://raw.githubusercontent.com/arthurcelestinoe/Artix-Extra-Packages/master/keys/artix-extra-unofficial.asc \
     | sudo pacman-key --add -
   sudo pacman-key --lsign-key BD87D7B0AADAA10656F9D04A8C8EF2FAA136031C
   ```

2. Add to the end of `/etc/pacman.conf`:

   ```ini
   [artix-extra-unofficial]
   SigLevel = Required
   Server = https://github.com/arthurcelestinoe/Artix-Extra-Packages/releases/download/repo
   ```

3. Run `sudo pacman -Sy` and install as usual. For services, also install the
   package for your init: `sudo pacman -S <package> <package>-openrc` (or
   `-runit`, `-s6`, `-dinit`, when available).

## How it works

Packages are grouped by the first letter of their name, and init packages sit
next to the program:

```
packages/
├── f/
│   ├── foo/
│   │   ├── PKGBUILD          downloads the source straight from upstream
│   │   └── .nvchecker.toml   where to look for new versions
│   └── foo-openrc/           init package (services only)
│       ├── PKGBUILD
│       ├── foo.initd
│       └── foo.confd
└── 0/
    └── 0ad/                  names starting with a digit work too
templates/                    templates for new packages
```

A package outside the folder of its initial (for example, `packages/b/foo`)
makes CI fail.

- **`update.yml`** runs every day. It queries each package's upstream with
  [nvchecker](https://github.com/lilydjwg/nvchecker), which understands tags
  from any git repository, GitHub Releases, GitLab, Gitea/Codeberg, PyPI,
  crates.io and more. For each new version, it updates `pkgver` and the
  checksums, test-builds the package and opens a PR.
- **`build.yml`** runs when something under `packages/` changes on `master`.
  It builds the changed packages in the `artixlinux/artixlinux:base-devel`
  container, signs them with GPG and publishes them to the `repo` Release,
  which is the pacman repository. Old versions are deleted from the Release
  after the new ones are uploaded.

## Adding a package

The quickest way is to start from Arch's packaging. It already uses the
upstream source and almost always has a `.nvchecker.toml`:

```bash
scripts/import-arch.sh <package>
```

The script lists everything that mentions systemd. Then:

1. Replace `systemd`/`systemd-libs` dependencies with `elogind`/`libelogind`,
   where applicable.
2. Remove the installation of `.service`/`.socket`/`.timer` files.
3. If it is a service, create the init package following the
   [Artix conventions](#init-packages). There is an OpenRC example in
   [templates/package-openrc](templates/package-openrc).
4. Test locally on Artix: `scripts/build-package.sh <package>` (packages are
   written to `out/`).
5. Check the monitoring: `scripts/check-updates.sh <package>`.

For a package that doesn't exist on Arch, copy `templates/package` to
`packages/<initial>/<package>`.

## Contributing

Contributions are welcome through pull requests. Before proposing a package,
check that it fits the rules below.

### What is accepted

- Free or open source software, under a license approved by the
  [OSI](https://opensource.org/licenses) or the
  [FSF](https://www.gnu.org/licenses/license-list.html).
- Packages that are **not** in the official Artix repositories. Check
  [packages.artixlinux.org](https://packages.artixlinux.org) first.
- Packages built from the upstream source code.
- **Exception for toolchains missing from Artix:** when the build toolchain
  isn't packaged in Artix, its official upstream release may be downloaded as
  a source, with a checksum. In practice this means the Flutter SDK: in
  Flutter apps, the Flutter engine shipped in the package is the official
  prebuilt one. The app itself and the native code of its plugins must still
  be built from source; prebuilt plugin libraries downloaded during the build
  are not accepted.

### What is not accepted

- **Proprietary software**, including freeware, binaries without source code
  and binary repackages (`-bin`).
- **Open source software whose trademark policy restricts third-party
  builds.** This covers projects that don't allow distributing a version built
  by someone else, or with patches, under the official name and logo, such as
  Firefox. The code is free, but the package would end up requiring
  rebranding or permission from the trademark owner.
- Packages that depend on systemd to work.

### Init packages

The repository accepts scripts for any init system Artix supports: OpenRC,
runit, s6 and dinit. If the program is a service, **whoever proposes the
package must create the init package**, following the Artix conventions:

- **A separate PKGBUILD for each init**, in
  `packages/<initial>/<package>-<init>/`, apart from the main package. Don't
  use a split package.
- `arch=(any)` and a `pkgver` set to the date of the script's last change
  (`YYYYMMDD`), not the program's version.
- `provides=(init-<package>)` and `conflicts=(init-<package>)`, so that only
  one init package for the program is installed at a time.
- A dependency on the main package and on the init, with the files in the
  paths Artix uses:

  | Package            | `depends`              | Installed files |
  |--------------------|------------------------|-----------------|
  | `<package>-openrc` | `openrc`, `<package>`  | `/etc/init.d/<service>`, `/etc/conf.d/<service>` |
  | `<package>-runit`  | `runit`, `<package>`   | `/etc/runit/sv/<service>/run` |
  | `<package>-s6`     | `s6-base`, `<package>` | `/etc/s6/sv/<service>-srv/` and `/etc/s6/sv/<service>-log/` (s6-rc definitions), `/etc/s6/config/<package>.conf` |
  | `<package>-dinit`  | `dinit`, `<package>`   | `/etc/dinit.d/<service>` |

- When in doubt, use an init package from Artix itself as a reference.
  `openssh` has all four: `openssh-openrc`, `openssh-runit`, `openssh-s6` and
  `openssh-dinit`, on [packages.artixlinux.org](https://packages.artixlinux.org)
  (with the file list) and on
  [Artix's Gitea](https://gitea.artixlinux.org/packages/openssh-runit).

Sending the init you use and can test is enough. The others can come in
future contributions, from you or someone else.

### How to submit

1. Fork the repository and create `packages/<initial>/<package>/` with the
   `PKGBUILD` and `.nvchecker.toml` and, if it is a service,
   `packages/<initial>/<package>-<init>/`. The easiest way to start is with
   `scripts/import-arch.sh` or the `templates/package` and
   `templates/package-openrc` templates.
2. Build it on an up-to-date Artix with `scripts/build-package.sh <package>`
   and actually test the program and the service. Then run
   `scripts/lint-package.sh <package> out` to check the rules below.
3. Check that the monitoring finds the current version:
   `scripts/check-updates.sh <package>`.
4. Open the PR with one program at a time (the package and its init
   packages), stating:
   - the program's license;
   - which init you tested;
   - any patch applied and why.

The PR is automatically built and checked in a clean Artix container. On a
first contribution, the test only runs after the maintainer approves it.

`PKGBUILD` checklist:

- SPDX header with authorship and license (see
  [License and authorship](#license-and-authorship)).
- `license=()` with the SPDX identifier of **the program's** license.
- Sources downloaded from upstream, with checksums (`updpkgsums` fills them
  in). `SKIP` only for git sources.
- No `systemd`/`systemd-libs` dependency.
- No systemd unit (`.service`, `.socket`, `.timer`) installed.

### License and authorship

> [!IMPORTANT]
> Every PKGBUILD, init script and other packaging file submitted to this
> repository is subject to the [0BSD](LICENSE) license. By opening a PR, you
> agree to make your contribution available under that license.
>
> **Whoever proposes a PKGBUILD is responsible for the authorship declared in
> it.** By submitting, you declare that the authorship lines are true and that
> you have the right to license the content under 0BSD. This includes giving
> proper credit when the PKGBUILD is based on someone else's work (Arch, AUR
> or another repository).

The authorship and license of each file are stated at its top, with
[SPDX](https://spdx.dev/learn/handling-license-info/) tags in the
[REUSE](https://reuse.software/spec/) format:

```bash
# SPDX-FileCopyrightText: 2026 Your Name <your@email>
# SPDX-License-Identifier: 0BSD
# Maintainer: Your Name <your@email>

pkgname=foo
...
```

- **`SPDX-FileCopyrightText`**: one line per author, with the year of the
  contribution. Whoever makes a significant change adds their own line,
  without removing the previous ones.
- **`SPDX-License-Identifier`**: always `0BSD`. It is the license of the
  packaging file.
- **`Maintainer` / `Contributor`**: the Arch convention for who maintains the
  package. A maintainer who steps down becomes a `Contributor`.
- **Based on Arch:** Arch's packaging repositories also use 0BSD. Keep the
  original `Maintainer`/`Contributor` lines and add
  `# SPDX-FileCopyrightText: Arch Linux contributors`.
  `scripts/import-arch.sh` does this automatically.
- **Based on the AUR:** the AUR has no single license. Only submit it if the
  original author allows redistribution under 0BSD, and keep their credit.
- **Email:** it can be your GitHub `noreply` address or an obfuscated email
  (`name at domain dot com`).

Don't mix up the two license fields. The `SPDX-License-Identifier` header is
the license **of the PKGBUILD**, always 0BSD. The `license=()` inside the
PKGBUILD is the license **of the packaged program**, for example
`GPL-3.0-or-later` or `MIT`.

## Known limitations

- If the package you want to propose depends on another one that isn't in
  this repository yet, submit the dependency first, in a separate PR. The PR
  test only finds dependencies that have already been published.
- `-git` packages, which track commits instead of versions, are not accepted
  for now: the monitoring only follows tags and releases.
- Packages with an epoch (`1:2.0-1`) are published with `.` instead of `:` in
  the file name, because GitHub doesn't accept `:` in Release files. This
  doesn't affect installation.

## License

The packaging files in this repository (PKGBUILDs, init scripts, scripts and
workflows) are under the [0BSD](LICENSE) license. Each packaged program keeps
its own license, stated in the PKGBUILD's `license=()` field and installed in
`/usr/share/licenses/<package>`.
