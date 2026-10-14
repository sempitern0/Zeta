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

**Parity is not a promise of byte-identical HTML.** Pandoc versions, timestamps and some diagnostics can differ. Both engines now create the same two Markdown showcase posts from shared source templates and render the same workspace index layout. Compare generated artifacts before changing production build environments.

## Check Bash locally

~~~bash
make syntax
bash tests/theme-smoke.sh
bash tests/workspace-parity-smoke.sh
bash tests/catalog-smoke.sh   # All eight themes
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
.\tests\powershell-workspace-smoke.ps1
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

## Markdown multipage regressions

Run `bash tests/pages-bash-smoke.sh` or `.\tests\pages-powershell-smoke.ps1` for blog-free static site builds in each of the eight themes. The smoke tests assert clean URLs, relative Markdown links, draft exclusion and sitemap entries. These are local tests; GitHub Actions are not needed.

## Doctor 2.0: Markdown source integrity

Both Bash (`./zeta.sh doctor SITE`) and PowerShell (`.\zeta.ps1 doctor SITE`) now invoke the same Pandoc Lua diagnostic filter without modifying source files. They report invalid YAML/frontmatter, local Markdown links pointing to missing files, missing image assets, unsafe link schemes, and images without alternative text. Errors (`FAIL`) block deployment readiness; missing alternative text produces a `WARN`.

Run `bash tests/doctor-content-bash-smoke.sh` and `.\tests\doctor-content-powershell-smoke.ps1` to verify known-bad documents are correctly diagnosed. The smoke tests create temporary site folders and clean them afterward; they never run GitHub Actions.

This source-level validation does not yet validate every rendered URL or guarantee that an external HTTP link is reachable. Those checks are later enhancements to Doctor.

## Doctor 2.0 — Published HTML and sitemap

Doctor now audits every generated HTML page and the sitemap read-only through
`templates/common/filters/doctor-public.lua`, shared by Bash and PowerShell.

It checks published local links to HTML/CSS/images, HTML titles, descriptions,
canonical URLs, document language, sitemap URL origins, duplicates, missing
indexed routes and HTML files omitted from the sitemap.

- FAIL: broken local asset/link; duplicate or wrong canonical; duplicate
  sitemap location; indexed route without output; missing HTML title
- WARN: absent description, canonical or language; missing sitemap entry

Missing metadata is a warning because the current themes do not all emit
complete SEO tags yet. Doctor never requests external URLs and never rewrites
the generated HTML.

Local regression checks:

~~~bash
bash tests/doctor-content-bash-smoke.sh
bash tests/doctor-public-bash-smoke.sh
~~~

~~~powershell
.\tests\doctor-content-powershell-smoke.ps1
.\tests\doctor-public-powershell-smoke.ps1
~~~

Tests use a local Pandoc executable. GitHub Actions is not involved.

## Shared SEO pipeline and quality summary

Bash and PowerShell run the same `seo-publish.lua` filter while their output is still in the staging directory. It creates/normalizes canonical, description, Open Graph and Twitter metadata for each generated HTML route; a failed filter does not replace the previous published directory. The optional `site.image` provides social preview imagery only when valid.

Doctor displays a heuristic score using the same formula in both shells: `max(0, 100 - 15 × FAIL - 3 × WARN)`, as well as category counts and tailored advice. This score is not a search ranking or a Lighthouse score.

Regression tests:

~~~bash
bash tests/seo-bash-smoke.sh
bash tests/theme-smoke.sh
bash tests/doctor-content-bash-smoke.sh
~~~

~~~powershell
.\tests\seo-powershell-smoke.ps1
.\tests\powershell-build-smoke.ps1
.\tests\doctor-content-powershell-smoke.ps1
~~~

No GitHub Actions or third-party web service is required.
