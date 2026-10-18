<h1 align="center">
  <img src="docs/assets/zeta-terminal-logo.svg" width="640" alt="Zeta — terminal ASCII wordmark">
</h1>

<p align="center"><strong>Write Markdown. Build static sites. Publish anywhere.</strong></p>
<p align="center">
  A terminal-first static site generator with native Bash and PowerShell assistants, powered by Pandoc.
  No database, CMS, Node.js build stack or application server required to host the result.
</p>
<p align="center"><strong>English</strong> · <a href="README_ES.md">Español</a></p>

---

## Why Zeta?

Zeta turns Markdown into a complete, deployable website while keeping authorship and site management in the terminal.

- **Two native assistants:** Bash 4.3+ on Linux/macOS and PowerShell 7+ on Windows, with interactive menus and direct commands.
- **Markdown-first:** pages, blog articles and metadata remain editable files under `sites/`.
- **Eight distinct themes:** `zen`, `paper`, `console`, `indie`, `organization`, `brutalist`, `folio` and `aurora`, with responsive layouts.
- **Reader-friendly articles:** Pandoc-generated contents navigation with theme-specific styling, a sticky desktop sidebar and a smaller-screen fallback.
- **Built-in publishing essentials:** navigation, category/tag archives, related articles, RSS/Atom, sitemaps, canonical URLs and structured metadata.
- **Portable static output:** publish generated HTML, CSS and local assets to any compatible static host. No CMS or server-side runtime is needed.

The optional active-section indicator uses a small local script; **Zeta does not require a JavaScript framework**. Authoring and building happen locally.

## Quick start

Clone the repository:

~~~sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
~~~

| Platform | Requirements to build | Local preview |
| --- | --- | --- |
| Linux / macOS | Bash **4.3+** and [Pandoc](https://pandoc.org/installing.html) | Python 3 (optional) |
| Windows | [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) and Pandoc | Built-in .NET server |

> You can create and edit site sources before installing Pandoc; Pandoc is required to build HTML. The Bash version bundled with macOS is older than Zeta's minimum, so install a newer Bash. Windows requires neither Bash nor WSL.

### Bash · Linux / macOS

~~~bash
./zeta.sh deps
./zeta.sh create
# Choose "my-site" as the site slug in the assistant:
./zeta.sh build my-site
./zeta.sh doctor my-site
./zeta.sh preview my-site
~~~

### PowerShell · Windows

~~~powershell
.\zeta.ps1 deps
.\zeta.ps1 create
# Choose "my-site" as the site slug in the assistant:
.\zeta.ps1 build my-site
.\zeta.ps1 doctor my-site
.\zeta.ps1 preview my-site
~~~

On Windows, `.\zeta.ps1 install-pandoc` offers a confirmed Pandoc installation through `winget`; the [official installer](https://pandoc.org/installing.html) also works. Launch either entry point with **no arguments** for its interactive menu, or use `help` to inspect commands.

Preview serves the generated site locally on port **8000** by default; stop it with Ctrl+C. The Bash and PowerShell assistants offer equivalent workflows but follow their shell's native option syntax.

## Authoring a site

A typical site keeps its source files separate from its generated output:

~~~text
sites/my-site/
├── config.yaml          # Site URL, title, language, theme and build paths
├── pages/
│   ├── index.md         # Markdown homepage
│   └── about.md         # Optional pages
├── posts/               # Markdown blog articles (if enabled)
├── assets/              # Images and optional locally installed fonts
├── styles/              # Optional site-specific CSS overrides
└── public/              # Generated files: publish this directory only
~~~

The creation wizard can include a blog, an About page and a Contact page. Article metadata uses Markdown frontmatter, for example:

~~~markdown
---
title: "Building with Zeta"
description: "My first Markdown article."
date: "2026-10-18"
category: "Projects"
tags: [markdown, static-sites]
---

## Introduction

Write in **Markdown**, then rebuild the site.

## Next steps

Create another section to populate the article's contents navigation.
~~~

Use the assistant to manage content or edit `pages/*.md`, `posts/*.md` and `config.yaml` directly. For navigation, drafts, tags, categories and related articles, see [Pages](docs/pages.md) and [Content](docs/advanced-content.md).

## Themes and customization

| Theme | Design direction | Ideal for |
| --- | --- | --- |
| `zen` | Dark and minimal | Technical writing |
| `paper` | Light editorial typography | Long-form articles |
| `console` | Terminal-inspired | DevOps and engineering |
| `indie` | Game-development identity | Games and devlogs |
| `organization` | Clean and structured | Open-source projects |
| `brutalist` | Bold, high-contrast | Experimental portfolios |
| `folio` | Refined serif and generous space | Personal portfolios |
| `aurora` | Dark gradients and luminous accents | Digital products |

Switch themes without rewriting your Markdown:

~~~bash
./zeta.sh theme my-site aurora zenburn
./zeta.sh fonts my-site recommended  # Optional local open-source coding font
./zeta.sh dashboard                  # Browse the eight theme previews
~~~

PowerShell equivalents use `.\zeta.ps1`. Fonts are optional and stored locally. The selected theme also styles Markdown pages and article contents navigation. Read the [theme catalog](docs/theme-catalog.md) and [landing guide](docs/landing-themes.md) for layouts, configuration and CSS overrides.

## Shared commands

| Command | Purpose |
| --- | --- |
| `create` / `sites` | Create a site / list existing sites |
| `edit SITE` | Update metadata and site settings |
| `pages SITE` / `new-page SITE TITLE SLUG` | List / create standalone pages |
| `posts SITE` / `new-post SITE` | List / create blog articles |
| `theme SITE THEME STYLE` | Set theme and Pandoc syntax-highlighting style |
| `fonts SITE [recommended]` | Manage optional local coding fonts |
| `build SITE` / `build-all` | Generate one / all sites |
| `doctor SITE` | Diagnose source content and published output |
| `preview SITE` | Build and preview a site locally |
| `dashboard` / `serve` | Generate / serve the local workspace catalog |
| `clean SITE` / `delete SITE` | Remove generated output / delete a site |

For an alternate preview port use `./zeta.sh --port 8080 preview my-site` or `.\zeta.ps1 preview my-site -Port 8080`. `main.sh` remains a legacy Bash entry point.

## Build, validate and publish

1. Set `site.url` in `sites/my-site/config.yaml` to your real production URL (including any hosting subpath).
2. Run `build SITE` and then `doctor SITE`. Preview pages and article navigation in a browser.
3. Deploy **only `sites/my-site/public/`** (or the configured output directory). Keep Markdown sources and site configuration private to your authoring workspace.

Zeta stages builds before replacing the published output; a failed build preserves the previous generated site. Doctor reports broken local links, assets and metadata, plus a **heuristic** quality score—not a Lighthouse score or search ranking. Read [Deployment](docs/deployment.md) and [SEO](docs/seo.md) for hosting and metadata details.

## Documentation and development

| Guide | Topic |
| --- | --- |
| [Terminal assistant](docs/terminal-assistant.md) | Menu navigation and command behavior |
| [Markdown pages](docs/pages.md) | Navigation, frontmatter, drafts and clean URLs |
| [Advanced content](docs/advanced-content.md) | Categories, tags and related content |
| [Theme catalog](docs/theme-catalog.md) | All eight themes, fonts and article contents |
| [Landing pages](docs/landing-themes.md) | Hero content, calls to action and project cards |
| [PowerShell](docs/powershell.md) | Native Windows setup and troubleshooting |
| [SEO](docs/seo.md) | Canonicals, structured data, sitemaps and feeds |
| [Deployment](docs/deployment.md) | Publish the generated site |
| [Validation](docs/cross-platform-validation.md) | Test suites, parity and known boundaries |

Useful local checks:

~~~bash
make syntax        # Bash syntax
make test-tooling  # Tooling regressions, without Pandoc
make test          # All Bash smoke tests (Pandoc required)
make lint          # ShellCheck, when installed
~~~

PowerShell has a separate test suite documented in [Validation](docs/cross-platform-validation.md). Both assistants use the same themes and Markdown sources, but byte-identical HTML between platforms or Pandoc versions is not guaranteed.

Contributions are welcome—see [CONTRIBUTING.md](CONTRIBUTING.md). Distributed under the [MIT license](LICENSE).
