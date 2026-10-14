# Zeta

Create static sites from Markdown with a native **Bash or PowerShell assistant**.
Pandoc generates the HTML; hosting needs no database, CMS or JavaScript framework.

**English** · [Español](README_ES.md)

## Quick start

```sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
```

| Platform | Requirements | Entry point |
|---|---|---|
| Linux / macOS | Bash 4.3+, Pandoc; Python 3 for preview | `./zeta.sh` |
| Windows | PowerShell 7+, Pandoc for builds | `.\zeta.ps1` |

macOS's bundled Bash is too old: use Bash 4.3+. Windows needs neither Bash nor WSL.
Install [Pandoc](https://pandoc.org/installing.html) to generate HTML. Site creation
itself does not require Pandoc. Run `deps` to inspect available dependencies.

```bash
./zeta.sh create            # Choose slug, theme, and optional blog/About/Contact
# Example below assumes you chose the slug my-site:
./zeta.sh build my-site
./zeta.sh preview my-site
```

```powershell
.\zeta.ps1 create
.\zeta.ps1 build my-site
.\zeta.ps1 preview my-site
```

Preview uses localhost port 8000. Stop it with Ctrl+C. Run either entry point
without arguments for the menu, or with `help` for all commands.

## Write → build → check → publish

| Edit | Purpose |
|---|---|
| `sites/my-site/pages/index.md` | Homepage |
| `sites/my-site/pages/about.md` | Optional About page |
| `sites/my-site/pages/*.md` | Other static pages, such as Contact or Privacy |
| `sites/my-site/posts/*.md` | Blog articles, when the blog is enabled |
| `sites/my-site/config.yaml` | Title, description, production URL, theme and build directories |
| `sites/my-site/assets/` | Images and optional local fonts |

Example page:

```markdown
---
title: "About"
description: "What we build and why."
nav: true
nav_order: 20
---
# About us

We build useful tools. [Back home](index.md).
```

Set `site.url` to your real public URL, replace/remove the example posts, then run:

```bash
./zeta.sh build my-site
./zeta.sh doctor my-site
./zeta.sh preview my-site
```

Use the same commands with `.\zeta.ps1` on Windows. **Publish only
`sites/my-site/public/`** (or your configured output directory). Rebuild after
editing Markdown; never edit generated HTML as your source of truth. A failed
build preserves the previous published output. See [deployment](docs/deployment.md).

## Shared commands

| Command | Task |
|---|---|
| `create` / `sites` | Create or list sites |
| `edit SITE` | Configure metadata and appearance |
| `pages SITE` / `new-page SITE "Privacy policy" privacy` | List or create static pages |
| `posts SITE` / `new-post SITE` | List or create articles |
| `theme SITE THEME STYLE` / `fonts SITE` | Theme, highlighting and local fonts |
| `build SITE` / `build-all` | Generate one/all sites |
| `doctor SITE` | Diagnose source, links, metadata and sitemap |
| `preview SITE` / `dashboard` | Preview one site / refresh the workspace catalog |
| `clean SITE` / `delete SITE` | Remove generated output / delete a whole site |

For a different preview port: `./zeta.sh --port 8080 preview my-site` or
`.\zeta.ps1 preview my-site -Port 8080`. `main.sh` remains the legacy Bash wrapper.
Doctor's quality score is a heuristic, not a Lighthouse or search-engine score.

## Guides and maintenance

| Need | Guide |
|---|---|
| Markdown pages, navigation and drafts | [Pages](docs/pages.md) |
| Blog categories, tags and related articles | [Content](docs/advanced-content.md) |
| Choose from eight themes | [Theme catalog](docs/theme-catalog.md) |
| Hero images, CTAs and project cards | [Landing themes](docs/landing-themes.md) |
| Canonical URLs and social metadata | [SEO](docs/seo.md) |
| Windows installation and preview | [PowerShell](docs/powershell.md) |
| Navigate the terminal menus | [Assistant](docs/terminal-assistant.md) |
| Local tests and platform differences | [Validation](docs/cross-platform-validation.md) |

```bash
make syntax        # Bash parsing; no system changes
make test-tooling  # Hook and lint regression tests, without Pandoc
make test          # All Bash smoke tests; requires Pandoc
make lint          # Requires an explicitly installed ShellCheck
```

`make setup` optionally prepares the workspace and installs the pre-commit hook.
The hook checks staged shell files and does not rewrite your working tree.
Both engines share Markdown/YAML and themes; byte-identical HTML across platforms
and Pandoc versions is not guaranteed. PowerShell has its own [test suite](docs/cross-platform-validation.md#check-powershell-locally).

[MIT license](LICENSE).
