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

## Five built-in themes

| Theme | Best for |
| :-- | :-- |
| `zen` | Minimal dark publishing |
| `paper` | Light, editorial reading |
| `console` | Systems administration and technical notes |
| `indie` | Indie game landing page and devlog |
| `organization` | Open-source organization and project directory |

All five themes run with either shell. The `indie` and `organization` layouts support hero images, CTAs and external project links; see [landing themes](docs/landing-themes.md). Optional self-hosted fonts include Cascadia Code, JetBrains Mono, Fira Code, IBM Plex Mono and Source Code Pro.

## Build and publish

`build` converts Markdown and themes to static HTML in `sites/<site>/public/`. **Publish only `public/`**, never `posts/` or `config.yaml`. Generation uses a staging directory before replacing the previous output.

`preview` serves localhost on port 8000 by default: Bash uses optional Python 3, PowerShell the built-in .NET HTTP listener. In PowerShell, stop the server with **Ctrl+C** or **Q** in compatible terminals.

Publish to any static host, including GitHub Pages, Cloudflare Pages or Netlify. See [deployment](docs/deployment.md).

## Guides and local tests

- [Windows / PowerShell](docs/powershell.md) — setup, Pandoc and preview.
- [Terminal assistant](docs/terminal-assistant.md) — navigation on both platforms.
- [Landing themes](docs/landing-themes.md) — hero images and project cards.
- [Deployment](docs/deployment.md) — static hosting and public URLs.
- [Cross-platform validation](docs/cross-platform-validation.md) — local smoke tests and limitations.

~~~bash
make syntax
bash tests/theme-smoke.sh
~~~

~~~powershell
.\tests\powershell-create-smoke.ps1
.\tests\powershell-build-smoke.ps1
.\tests\powershell-server-smoke.ps1
~~~

The engines share an authoring format and command surface; **byte-identical output across Pandoc versions is not guaranteed**. Local validation does not require GitHub Actions.

**License:** [MIT](LICENSE).
