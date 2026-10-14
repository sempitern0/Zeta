# Zeta

**One Markdown-first static site generator. Two native terminal assistants: Bash and PowerShell.**

Build blogs, technical notes, game landing pages and project showcases with **Pandoc** and ordinary files. No CMS, database, Node.js or JavaScript framework is required to build or host the site.

| Linux / macOS | Windows |
| :-- | :-- |
| **Bash 4.3+** · `./zeta.sh` | **PowerShell 7+** · `.\zeta.ps1` |

**Both assistants use the same Markdown posts, YAML configuration, themes and generated HTML structure.** Author on Windows and continue on Linux without converting your site. `main.sh` remains a compatibility wrapper for older Bash scripts.

[Español](README_ES.md)

## Quick start

Clone once:

~~~sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
~~~

### Linux / macOS (Bash)

Requires Bash 4.3+ and [Pandoc](https://pandoc.org/installing.html) to build HTML. Python 3 is optional for local preview. The default macOS Bash is too old; use a newer Bash.

~~~bash
make setup
./zeta.sh                  # Interactive assistant
./zeta.sh create
./zeta.sh build my-site
./zeta.sh preview my-site
~~~

### Windows (native PowerShell)

Requires PowerShell 7+. **No Bash or WSL required.** You can create sites before installing Pandoc; only HTML generation needs it.

~~~powershell
.\zeta.ps1 deps            # Check Pandoc
.\zeta.ps1 install-pandoc  # Optional, confirmed winget installation
.\zeta.ps1                 # Interactive assistant
.\zeta.ps1 create
.\zeta.ps1 build my-site
.\zeta.ps1 preview my-site -Port 8000
~~~

If Windows Package Manager is unavailable, install Pandoc manually from [pandoc.org](https://pandoc.org/installing.html). See the [Windows setup guide](docs/powershell.md).

## Shared commands

Run the **same command** after `./zeta.sh` in Bash or `.\zeta.ps1` in PowerShell:

| Command | Purpose |
| :-- | :-- |
| `create` | Create a site through the assistant |
| `sites` | List sites and their status |
| `edit SITE` | Edit site configuration and appearance |
| `posts SITE` / `new-post SITE` | List / create Markdown articles |
| `theme SITE THEME STYLE` | Change the theme and code highlighting |
| `fonts SITE` | Manage optional local fonts |
| `build SITE` / `build-all` | Generate HTML for one / every site |
| `doctor SITE` | Check publishing readiness |
| `preview SITE` / `serve` | Preview a site / serve the workspace |
| `dashboard` | Refresh the workspace index |
| `clean SITE` / `delete SITE` | Remove generated output / delete a site |

The console assistants offer a colorful ZETA dashboard and numbered menus. Port flags are shell-native: `./zeta.sh --port 8080 preview my-site` versus `.\zeta.ps1 preview my-site -Port 8080`. Use `help` to inspect all options.

## Markdown pages and optional blog

The site-creation assistant asks whether to include **Blog**, **About** and **Contact**. Every new site gets a Markdown homepage in `pages/index.md`; other pages generate clean static URLs such as `/about/`, with accessible navigation. A site without a blog publishes no article archive or blog URLs.

Create additional pages with `./zeta.sh new-page SITE "Privacy policy" privacy` in Bash or `.\zeta.ps1 new-page SITE "Privacy policy" privacy` in PowerShell; use `pages SITE` to list them. Page metadata controls navigation order and drafts. See the [Markdown pages guide](docs/pages.md).

## Shared visual workspace and starter content

Both assistants now build the **same responsive and keyboard-accessible workspace index** at `sites/index.html`, with a shared stylesheet, site status, description, theme, article count and a preview link when a build exists. An empty workspace remains usable, and a broken site's configuration cannot hide healthy sites.

Creating a site in either shell produces **two complete Markdown demonstrations**: `zeta-markdown-showcase.md` (formatting, tables, footnotes, lists) and `zeta-code-showcase.md` (syntax-highlighted code across languages). The examples and dashboard assets are maintained once under `templates/common/`. PowerShell builds `public/` automatically when Pandoc is present; Bash builds on demand.

## Site layout

~~~text
sites/my-site/
├── config.yaml        # Site metadata and build settings
├── posts/             # Markdown sources
├── landing.yaml       # Optional landing controls
├── landing.md         # Optional landing introduction
├── styles/            # Optional CSS overrides
├── assets/            # Optional images and fonts
└── public/            # Generated files: deploy ONLY this folder
    ├── index.html
    ├── posts.html
    ├── posts/
    ├── styles/
    ├── robots.txt
    └── sitemap.xml
~~~

Example `config.yaml`:

~~~yaml
site:
  title: "My site"
  description: "Projects and technical notes"
  author: "Ada"
  language: "en"
  url: "https://example.com"

theme:
  name: "zen"
  pandoc_theme: "zenburn"

build:
  content_dir: "posts"
  output_dir: "public"
~~~

Posts are `.md` files with optional YAML frontmatter such as `title`, `date`, `description`, `slug` and `tags`. Set `site.url` to the real public URL before deployment: Zeta uses it for `sitemap.xml` and `robots.txt`.

## Eight built-in themes

| Theme | Best for |
| :-- | :-- |
| `zen` | Minimal dark publishing |
| `paper` | Light, editorial reading |
| `console` | Systems administration and technical notes |
| `indie` | Indie game landing page and devlog |
| `organization` | Open-source organization and project directory |
| `brutalist` | High-contrast graphic studio and manifesto |
| `folio` | Elegant portfolio and editorial writing |
| `aurora` | Digital product and atmospheric technology landing |

All eight themes work with either shell. See the [full theme catalog](docs/theme-catalog.md). The `indie` and `organization` layouts additionally support hero images, CTAs and external project links; see [landing themes](docs/landing-themes.md). Optional self-hosted fonts include Cascadia Code, JetBrains Mono, Fira Code, IBM Plex Mono and Source Code Pro.

## SEO and Doctor quality report

Both Bash and PowerShell automatically normalize SEO metadata in the temporary build: canonical URLs, descriptions, Open Graph and social preview tags for every generated HTML page. Set an optional `site.image` (a published `assets/` file or an HTTPS URL) for social previews. The previous `public/` is preserved if generation fails.

Run `./zeta.sh doctor SITE` or `.\\zeta.ps1 doctor SITE` to check Markdown, published links, sitemap and SEO metadata. Doctor reports a heuristic 0–100 quality score, problem counts by category and concrete corrective steps. It is not a Google ranking or Lighthouse score.

See the [SEO guide](docs/seo.md) and [cross-platform validation](docs/cross-platform-validation.md).

## Categories, tags and related articles

Article frontmatter supports an optional `category` and multiple `tags`. Zeta automatically generates static archives at `/categories/` and `/tags/`, links each article to its topics, and recommends up to three related articles sharing categories or tags. The archives also participate in the sitemap and shared SEO pipeline; the whole process is JavaScript-free.

Both creation assistants ask for the category and tags. See the [advanced content management guide](docs/advanced-content.md).

## Build and publish

`build` converts Markdown and themes to static HTML in `sites/<site>/public/`. **Publish only `public/`**, never `posts/` or `config.yaml`. Generation uses a staging directory before replacing the previous output.

`preview` serves localhost on port 8000 by default: Bash uses optional Python 3, PowerShell the built-in .NET HTTP listener. In PowerShell, stop the server with **Ctrl+C** or **Q** in compatible terminals.

Publish to any static host, including GitHub Pages, Cloudflare Pages or Netlify. See [deployment](docs/deployment.md).

## Guides and local tests

- [Windows / PowerShell](docs/powershell.md) — setup, Pandoc and preview.
- [Terminal assistant](docs/terminal-assistant.md) — navigation on both platforms.
- [Theme catalog](docs/theme-catalog.md) — all eight designs and their uses.
- [Landing themes](docs/landing-themes.md) — hero images and project cards.
- [Deployment](docs/deployment.md) — static hosting and public URLs.
- [Cross-platform validation](docs/cross-platform-validation.md) — local smoke tests and limitations.

~~~bash
make syntax
bash tests/theme-smoke.sh
bash tests/workspace-parity-smoke.sh
bash tests/catalog-smoke.sh
~~~

~~~powershell
.\tests\powershell-create-smoke.ps1
.\tests\powershell-workspace-smoke.ps1
.\tests\powershell-build-smoke.ps1
.\tests\powershell-server-smoke.ps1
~~~

The engines share an authoring format and command surface; **byte-identical output across Pandoc versions is not guaranteed**. Local validation does not require GitHub Actions.

**License:** [MIT](LICENSE).
