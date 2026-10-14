# SEO publishing in Zeta

Zeta builds static websites without JavaScript. Metadata improves discoverability and link previews, but search rankings also depend on editorial quality, correct hosting, accessible HTML and search-engine crawling.

## Implemented: shared build-time SEO

All eight themes, Markdown pages, the home page, blog archive and articles use the same Pandoc Lua filter: `templates/common/filters/seo-publish.lua`. Both Bash and PowerShell run it against the **temporary build directory, before publishing**. An SEO failure stops publication and preserves the existing `public/`.

Every generated HTML file receives a single canonical URL, description, Open Graph type/title/description/url/site name, and Twitter card metadata. Existing duplicate descriptions, canonical links and OG/Twitter tags are normalized. Repeated processing is idempotent.

Canonical URLs use `site.url` and the actual published location (for example `/about/` or `/posts/2026/example.html`). The page's existing HTML title and description are preferred, with the site metadata as fallback. Articles receive `article:published_time` when the HTML contains a usable `<time datetime="YYYY-MM-DD">` element.

### Optional social cover

In `sites/YOUR-SITE/config.yaml`:

~~~yaml
site:
  title: "My site"
  description: "My website introduction."
  url: "https://example.org"
  image: "assets/social-cover.webp"
~~~

`site.image` is optional. Supported forms are a published, local `assets/` file or an absolute HTTPS image URL. Local images are only included when they exist in the staged public assets. Invalid or missing images are omitted instead of producing broken OG tags. An available image enables the Twitter large preview; otherwise the summary card is used. A preexisting `og:image` in the rendered page may take precedence.

For page-specific descriptions, set `description` in Markdown frontmatter:

~~~yaml
---
title: "About"
description: "A brief explanation of who we are and what we do."
---
~~~

## Doctor quality report

`./zeta.sh doctor SITE` and `.\zeta.ps1 doctor SITE` report errors, warnings, a **heuristic quality score from 0 to 100**, category counts and suggested corrective actions. Categories include links/assets, SEO/metadata, content, publishing, and configuration.

The score is calculated as `max(0, 100 - 15 × FAIL - 3 × WARN)` and is **not** a Google Lighthouse/PageSpeed score, a search-ranking prediction or a replacement for manual accessibility testing.

Doctor checks source Markdown as well as published HTML, local links, canonical links and sitemap consistency. No files are changed during the diagnosis.

## Local validation (no GitHub Actions)

~~~bash
bash tests/seo-bash-smoke.sh
bash tests/doctor-public-bash-smoke.sh
bash tests/doctor-content-bash-smoke.sh
~~~

~~~powershell
.\tests\seo-powershell-smoke.ps1
.\tests\doctor-public-powershell-smoke.ps1
.\tests\doctor-content-powershell-smoke.ps1
~~~

The SEO tests cover clean canonical routes, social images, valid article dates, escaping, duplicate removal and idempotence. Pandoc must be installed.

## Remaining enhancements

Automatic per-post social-image selection, validated Schema.org JSON-LD, RSS/Atom, accurate modification dates in the sitemap, deeper accessibility audits and online link reachability are **not** part of this iteration. Current sitemap generation may still report build-time dates rather than source modification dates; do not treat its `lastmod` values as verified editorial updates.
