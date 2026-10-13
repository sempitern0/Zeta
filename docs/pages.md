# Markdown pages in Zeta

[← README](../README.md) · [Theme catalog](theme-catalog.md)

Zeta produces full static sites using Markdown and Pandoc with no JavaScript. Both native assistants have the same page workflow.

## Site creation

Run `./zeta.sh create` (Bash) or `.\zeta.ps1 create` (PowerShell). After metadata and theme, select Blog (default Yes), About (default Yes) and Contact (default No). Every new site contains `pages/index.md`.

| Source | Generated URL |
| --- | --- |
| `pages/index.md` | `/index.html` |
| `pages/about.md` | `/about/index.html` / `/about/` |
| `pages/contact.md` | `/contact/index.html` / `/contact/` |
| `posts/*.md` (blog enabled) | `/posts/YYYY/slug.html` |

A blog-free site omits the archive, blog articles and blog URLs from `sitemap.xml`. Publish only `public/`, not the Markdown sources. Static hosts must support directory indexes for clean `/about/`-style URLs.

## Create additional pages

Use `./zeta.sh pages my-site` or `.\zeta.ps1 pages my-site` to list pages.

Use `./zeta.sh new-page my-site "Privacy" privacy` or `.\zeta.ps1 new-page my-site "Privacy" privacy` to create and build a Markdown page. Supported page filenames are lowercase letters, digits and hyphens.

Markdown page frontmatter:

~~~yaml
---
title: "About"
description: "Meet our team."
menu_title: "Our team"
nav: true
nav_order: 20
draft: false
---

## Hello

Read our [contact page](contact.md).
~~~

`nav: false` hides a page from the menu without removing it from search-engine indexes. `draft: true` excludes it from the generated files, menu and sitemap. Pages are sorted by `nav_order`; the currently active page uses `aria-current="page"`.

A shared Pandoc Lua filter converts `[Contact](contact.md)` into an appropriate relative link to the static page. Use Markdown links instead of hardcoding server URLs.

## Security and publishing

The page renderer disables raw HTML and discards executable or protocol-relative Markdown links. It emits semantic HTML, a skip link, canonical URL, description, responsive CSS and **no client-side JavaScript**. For additional protection publish with HTTPS and appropriate server headers; Zeta does not configure your host.

## Validation

Bash: `bash tests/pages-bash-smoke.sh`.
PowerShell: `.\tests\pages-powershell-smoke.ps1`.

Both local smoke tests create temporary sites with all eight themes, test draft exclusion, blog-free output, generated links and sitemap entries. They do not invoke GitHub Actions.
