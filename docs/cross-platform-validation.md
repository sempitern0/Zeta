# Cross-platform validation

[← Project overview](../README.md)

Zeta shares a **publishing format and command surface** across two engines:

| Bash (Linux/macOS) | PowerShell (Windows) |
| :-- | :-- |
| `./zeta.sh` | `.\zeta.ps1` |
| `lib/bash/` | `lib/powershell/` |
| Bash 4.3+ | PowerShell 7+ |
| Optional Python preview | Built-in .NET preview |

Both read the same `config.yaml`, Markdown articles and `templates/` and generate `sites/<site>/public/`. Arguments use each shell's conventions (e.g. `--port` and `-Port`).

**Parity is not a promise of byte-identical HTML.** Pandoc versions, timestamps and some diagnostics can differ. Bash currently creates two Markdown demonstration posts, whereas PowerShell creates one welcome post. Compare generated artifacts before changing production build environments.

## Check Bash locally

~~~bash
make syntax
bash tests/theme-smoke.sh
./zeta.sh help
./main.sh help    # Legacy entry point
~~~

`make lint` is also available when ShellCheck is installed.

## Check PowerShell locally

~~~powershell
.\zeta.ps1 deps
.\zeta.ps1 help
.\zeta.ps1 sites
.\tests\powershell-create-smoke.ps1
.\tests\powershell-build-smoke.ps1
.\tests\powershell-server-smoke.ps1
~~~

The PowerShell tests use temporary fixtures; the build test needs Pandoc. On an actual site run `doctor SITE` and check generated articles, styles, `sitemap.xml` and `robots.txt`.

These tests run **locally**, with no GitHub Actions minutes or Docker required.

## Source layout

~~~text
zeta.sh             Bash entry point
zeta.ps1            PowerShell entry point
main.sh             Legacy Bash compatibility
lib/bash/           Bash implementation
lib/powershell/     Native PowerShell implementation
templates/          Shared themes and assets
sites/              Source Markdown and generated HTML
tests/              Local regression scripts
~~~

See also [Windows setup](powershell.md) and [deployment](deployment.md).
