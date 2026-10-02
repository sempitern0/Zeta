# Zeta

Zeta turns Markdown posts into a deploy-ready static blog using **Bash + Pandoc**.

It deliberately keeps the workflow small:

1. Write Markdown in `sites/<site>/posts/`.
2. Build the site.
3. Preview it locally.
4. Deploy only `sites/<site>/public/`.

No database, JavaScript framework, Node.js runtime, CMS server, or application server is required to generate or host the site.

**Español:** [README_ES.md](README_ES.md)

## Requirements

Required:

- Bash 4.3+
- Pandoc

Optional:

- Python 3 — built-in local preview server
- Docker + Docker Compose — optional legacy Nginx/HTTPS development stack
- ShellCheck — contributor linting

Zeta does not install optional packages when the assistant starts. On macOS, install a current Bash with Homebrew because the system Bash is older than the required 4.3 release.

## Quick start

```bash
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
make setup
./main.sh
```

`make setup` checks the runtime, prepares `sites/`, validates Bash syntax, and installs the repository Git hook when applicable. It does **not** start Docker or modify `/etc/hosts`.

## Daily workflow

### 1. Create a site

Interactive:

```bash
./main.sh create
```

The site is created under:

```text
sites/my-blog/
├── config.yaml     # local build configuration
└── posts/          # local Markdown sources
```

After the first build:

```text
sites/my-blog/
├── config.yaml
├── posts/
└── public/         # deploy this directory only
    ├── index.html
    ├── posts.html
    ├── posts/
    ├── styles/
    ├── assets/        # only when the theme/site provides assets
    ├── robots.txt
    ├── sitemap.xml
    └── sitemap.xsl
```

`config.yaml` and `posts/` are authoring/build inputs. They are never copied into `public/` by Zeta.

### 2. Add a Markdown post

The quickest option is the assistant:

```bash
./main.sh new-post my-blog
```

Or create a file manually in `sites/my-blog/posts/`:

```markdown
---
title: "Deploying a small static site"
author: "Ada"
date: "2026-10-02"
description: "A practical deployment note."
slug: "deploying-a-small-static-site"
tags: [linux, devops, web]
---

# Deploying a small static site

Write the post in normal Markdown.
```

A date-prefixed filename is recommended:

```text
2026-10-02-deploying-a-small-static-site.md
```

### 3. List local posts

```bash
./main.sh posts my-blog
```

This reads Markdown metadata directly from `posts/`; no build is required.

For a fast update loop after copying a new Markdown file:

```bash
cp article.md sites/my-blog/posts/
./main.sh posts my-blog
./main.sh update my-blog
./main.sh preview my-blog
```

### 4. Build or update the static site

```bash
./main.sh build my-blog
```

Every build regenerates `public/` from the current Markdown and templates, which also removes stale generated pages. Zeta builds into a staging directory first and replaces `public/` only after a successful render, so a failed Pandoc run leaves the last valid artifact untouched.

Build every local site:

```bash
./main.sh build-all
```

### 5. Preview locally

Preview one site:

```bash
./main.sh preview my-blog
```

Default URL:

```text
http://127.0.0.1:8000/
```

Use another port:

```bash
./main.sh --port 8080 preview my-blog
```

Build every site and open the local workspace dashboard:

```bash
./main.sh serve
```

Then visit `http://127.0.0.1:8000/`. The dashboard links to each generated `public/` directory.

Python 3 is used only for this preview server. If it is not installed, `build` still works and `public/` can be served by any static HTTP server.

## Site management commands

| Command | Purpose |
| --- | --- |
| `./main.sh` | Open the interactive assistant |
| `./main.sh sites` | List local sites and build status |
| `./main.sh create` | Create a site |
| `./main.sh edit <site>` | Edit metadata, production URL and theme |
| `./main.sh delete <site>` | Delete a local site after explicit confirmation |
| `./main.sh clean <site>` | Delete generated `public/` only |
| `./main.sh posts <site>` | List Markdown posts |
| `./main.sh new-post <site>` | Create a Markdown post scaffold |
| `./main.sh build <site>` / `update <site>` | Regenerate one `public/` directory |
| `./main.sh build-all` | Regenerate all sites |
| `./main.sh preview <site> [port]` | Build and serve one site |
| `./main.sh serve [port]` | Build all sites and serve the local dashboard |
| `./main.sh dashboard` | Regenerate the local dashboard without serving it |
| `./main.sh --force ...` | Skip destructive confirmations where supported |

## `config.yaml`

A generated configuration stays intentionally small:

```yaml
site:
  title: "My Blog"
  description: "Notes about systems and software"
  author: "Ada"
  language: "en"
  url: "https://example.com"

theme:
  name: "zen"
  pandoc_theme: "zenburn"

build:
  content_dir: "posts"
  output_dir: "public"
```

Set `site.url` to the real production URL before deployment. Zeta uses it to generate absolute URLs in `sitemap.xml` and the sitemap reference in `robots.txt`.

For a GitHub Pages project site, include the repository path when it is part of the public URL, for example:

```yaml
url: "https://username.github.io/project"
```

Page navigation itself uses relative links, so the generated HTML remains portable between local preview, domain roots, and sub-path hosting.

## Deployment

The deployment contract is provider-independent:

```text
sites/<site>/public/
```

That directory is the complete static artifact. Do not upload `posts/` or `config.yaml`. Zeta intentionally keeps provider credentials and deployment SDKs out of the generator: build locally, then publish the artifact with the host you prefer.

### Netlify — simplest manual deployment

1. Run `./main.sh build <site>`.
2. Open Netlify Drop.
3. Drag `sites/<site>/public/` into the drop area.
4. For later updates, rebuild locally and drop the updated `public/` folder into the same site's deploy area.

Official guide: https://docs.netlify.com/start/quickstarts/netlify-drop-quickstart/

### Vercel Drop — simple manual deployment

1. Run `./main.sh build <site>`.
2. Open Vercel Drop.
3. Drop the `public/` folder.
4. Vercel serves the static files as-is; no framework is required.

Vercel Drop: https://vercel.com/drop

### Cloudflare Pages

For the local-source model used by Zeta, **Direct Upload** is the cleanest fit: build the site and upload the already-generated static assets from `public/`. No framework build is required on Cloudflare.

If you later create a separate Git repository that contains only deployable files, Pages can also publish that repository by configuring its static output directory.

Official docs:

- https://developers.cloudflare.com/pages/get-started/direct-upload/
- https://developers.cloudflare.com/pages/configuration/build-configuration/

### GitHub Pages

GitHub Pages can publish from a branch or via GitHub Actions.

The lowest-coupling Zeta workflow is to keep authoring sources local and copy the contents of `public/` to a dedicated Pages repository or publishing branch. Configure Pages to publish that branch from its repository root.

If you prefer CI, use a Pages Actions workflow that uploads the generated static artifact. Remember that a CI build from Markdown must install Pandoc before running Zeta.

Official guide: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

## HTML, CSS and browser behavior

The `zen` theme is intentionally server-free and JavaScript-free:

- semantic HTML5 output;
- relative navigation links;
- visible keyboard focus states;
- skip-to-content links;
- reduced-motion support;
- system/monospace font fallbacks;
- responsive layouts using ordinary CSS;
- no client-side framework or hydration step.

This keeps the generated output easy to inspect, cache, archive and serve from practically any static host.

## Optional Docker/Nginx development stack

The existing Docker/Nginx stack remains available for users who specifically want local HTTPS/proxy behavior. It is not required for the normal authoring loop; `preview` is the recommended public-only test path:

```bash
make docker-up
make docker-ps
make docker-down
```

It is no longer part of the default setup or the normal authoring loop.

## Contributor checks

Basic syntax check:

```bash
make syntax
```

ShellCheck, when installed explicitly:

```bash
make lint
```

## License

MIT. See [LICENSE](LICENSE).


## New-site smoke tests and optional fonts

Every newly created site starts with two Markdown example posts. Together they exercise headings, lists, tables, links, quotes and fenced code blocks in Bash, Python, JavaScript, YAML, JSON, CSS and HTML.

Optional web fonts are installed per site, not globally:

```bash
./main.sh fonts my-blog
```

The build always layers `templates/common` first, then the selected theme, then per-site overrides.


## Themes, Markdown rendering and code highlighting

Zeta currently ships with two themes:

- `zen`: dark, terminal-inspired.
- `paper`: light, editorial and reading-focused.

Change a site's appearance and immediately rebuild it:

```bash
./main.sh theme my-blog
```

Or choose it non-interactively:

```bash
./main.sh theme my-blog paper zenburn
```

The Markdown renderer uses Pandoc's extended Markdown support for pipe/grid tables,
definition lists, task lists, footnotes and fenced code blocks. Responsive tables
are wrapped with Pandoc's built-in Lua runtime; this adds no external dependency.

The selected Pandoc syntax style is embedded into each article, so styles such as
`zenburn`, `haddock`, `pygments`, `tango`, `espresso`, `kate` and `monochrome`
actually control token colors.

## Optional open-source fonts

Use the assistant or:

```bash
./main.sh fonts my-blog
```

Available font families:

- Cascadia Code
- JetBrains Mono
- Fira Code
- IBM Plex Mono
- Source Code Pro

Fonts are downloaded only for the selected site, stored under its local `assets/`
directory with the upstream license, and copied to `public/` during the next build.
Selecting a font from the assistant rebuilds the site automatically.


### Local font cache

Font downloads are cached once per checkout under `.zeta-cache/fonts/`. The
directory is ignored by Git. A second site using the same font reuses the cached
files and performs no network download; Zeta only copies the selected font into
that site's local `assets/fonts/` before building `public/`.
