# SEO automation checklist

Zeta is a static generator. Search visibility depends on the quality of Markdown content, a real `site.url`, accessible navigation, and successful crawling. Metadata alone does not guarantee rankings.

## Planned common build contract

Every published route (home, page, post, archive) should have exactly one:

- Unique title and description, with useful fallback text
- Absolute canonical URL derived from `site.url` and its actual output route
- Open Graph type/title/description/url/site_name; optional validated image
- Twitter summary card; large card only when a valid image is present
- Correct HTML `lang`, semantic landmarks and accessible links

Articles can additionally have a valid publication date and author. Do not invent update dates or structured data fields.

## Markdown fields

For pages and articles:

~~~yaml
---
title: "A useful page title"
description: "A brief summary of what the reader will find."
image: "assets/social-cover.webp"
draft: false
---
~~~

The optional `image` must be a public HTTPS URL or a local `assets/` file copied into the published site. Missing images should not create broken `og:image` links. The global fallback can be `site.image` in config.yaml.

## Sitemap

- Emit only actual published routes, exactly once each.
- Exclude drafts and disabled blogs; skip unbuilt or missing routes.
- Only emit `lastmod` when it can be verified from source metadata, not merely because a build ran today.
- Keep `robots.txt` and the sitemap's host in sync with `site.url`.
- If `site.url` still points to example.com, warn about production deployment.

## Build diagnostics

Warnings (not silent content rewriting): empty/duplicate titles; missing/oversized descriptions; absent image alt text; broken local Markdown links; canonical duplication; invalid dates; placeholder production domains.

Checks should inspect **final staged HTML**, and a failed SEO phase should preserve the previously generated `public/`.

## Acceptance test

Build a Markdown site and blog in Bash and PowerShell for all eight themes. Parse the final HTML, verify unique canonical/description/social tags per route, confirm valid sitemap and robots, verify no draft or disabled-blog routes, and compare functionality rather than byte-identical output.

This is an implementation checklist, not a claim that every item is already implemented.
