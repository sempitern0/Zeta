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

## RSS, Atom and Schema.org (implemented)

When Blog is enabled, Zeta generates **`public/rss.xml` and `public/atom.xml`**. Feeds contain the published articles' titles, URLs, summaries and publication dates when available. Each HTML page advertises the feeds through `<link rel="alternate">` elements. Sites without a blog do not generate feeds or advertise them.

The shared Pandoc filter `templates/common/filters/publish-extras.lua` also adds **Schema.org JSON-LD** to every published HTML page:

- `WebSite` for the homepage, `WebPage` for static pages and archives
- `BlogPosting` for articles, with URL, description, language, author and a publication date when present

This structured data uses only metadata that Zeta actually knows. It does not synthesize review scores or claims of rich-result eligibility. The JSON-LD is a data script (`type="application/ld+json"`), not executable browser JavaScript.

### Explicit modification dates

To indicate a genuine editorial update, add `updated` to the Markdown frontmatter:

~~~yaml
---
title: "Updated article"
date: "2026-10-10"
updated: "2026-10-14"
description: "A technical article with revised content."
---
~~~

Zeta generates `<lastmod>2026-10-14</lastmod>` in the sitemap for that article. Without `updated`, it omits `lastmod` rather than using the current build date. Invalid dates cause the shared publishing stage to fail before replacing the existing `public/`.

Both Bash and PowerShell create a temporary metadata map inside staging; the map is removed before the final site is published. Feeds and JSON-LD are generated from the already-rendered HTML, so they remain independent of themes and work with either engine.

## Remaining enhancements

Automatic per-post social-image selection, richer Schema.org entity types, deeper accessibility audits and online link reachability are not yet implemented. Sitemap `lastmod` values are emitted only for valid explicit `updated` dates.
