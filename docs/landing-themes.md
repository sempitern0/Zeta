# Landing themes · categories and portfolios

[← All themes](theme-catalog.md)

Zeta includes **`indie`** for game promotion and development logs and **`organization`** for open-source groups and project catalogs. Both run in **Bash and PowerShell** and reuse standard Markdown articles and site configuration.

## Choose a theme

~~~bash
./zeta.sh theme my-site indie zenburn
./zeta.sh theme my-site organization zenburn
~~~

~~~powershell
.\zeta.ps1 theme my-site indie zenburn
.\zeta.ps1 theme my-site organization zenburn
~~~

The theme command rebuilds the site. Use `sites/my-site/landing.md` for an introduction, features or mission written in Markdown.

## Optional landing settings

Create `sites/my-site/landing.yaml`:

~~~yaml
landing:
  eyebrow: "Open-source Godot tools"
  primary_label: "Explore on GitHub"
  primary_url: "https://github.com/Dragonboon"
  secondary_label: "Projects"
  secondary_url: "#updates"
  hero_image: "assets/hero.webp"
  hero_alt: "Promotional artwork"
~~~

Every field is optional. Put images in the site's `assets/` folder so they are copied to `public/assets/`. Landing content is kept separately from the selected theme and survives theme changes.

## External project links

Give a project's Markdown article an `external_url` to link its card directly to a repository or documentation:

~~~markdown
---
title: "Nucleus"
description: "Tools for Godot."
date: "2026-10-12"
external_url: "https://github.com/Dragonboon/Nucleus"
---

# Nucleus

Project details.
~~~

Without `external_url`, the card links to the article's generated page. With it, Zeta still builds the local article and includes it in the sitemap. Unsafe URL schemes are rejected.

Both themes provide responsive layouts and keyboard navigation; no live GitHub API is required. Publish only the generated `public/` folder.

**Related:** [deployment](deployment.md) · [Windows setup](powershell.md).


## Category landing designs

Seven category themes follow the existing Pandoc template contract. They work in Bash and PowerShell without extra frontend dependencies, external fonts or JavaScript.

| Theme | Use case | Visual treatment |
| --- | --- | --- |
| `music` | Artists, albums, live shows | Vinyl record and dark stage |
| `cuisine` | Chefs, recipes, restaurants | Warm recipe paper |
| `spirituality` | Mindfulness and reflection | Soft circular aura |
| `photography` | Photography portfolios | Framed imagery |
| `store` | Boutique collections | Product display |
| `services` | Agencies and consultancies | Structured technical grid |

### Display a themed homepage with Markdown pages

Zeta's creation wizard generates `pages/index.md`, which normally takes priority over a theme's designed homepage. To display the themed landing while retaining Markdown pages such as About and Contact, use:

```yaml
homepage:
  layout: theme  # Default is markdown
  show_posts: false
```

`homepage.layout` accepts `markdown` (default) or `theme`. Invalid values fail the build. The file `pages/index.md` stays on disk and is not overwritten. Switching back to `markdown` restores its published content on the next build. The hero uses your `landing.md` and `landing.yaml`; when no hero image is provided, a built-in CSS illustration appears. For a design-led landing, set `homepage.show_posts: false` to avoid inserting a separate feed into the hero.

```bash
./zeta.sh theme my-site music zenburn
./zeta.sh build my-site
./zeta.sh doctor my-site
./zeta.sh dashboard
```

Both assistants discover themes from their directories automatically. The dashboard now includes an example for each of the seven categories. Store and services are visual starting points, not e-commerce checkout or appointment-booking engines. Link CTAs to external providers as needed.

## Academy: educational publishing

`academy` adds a light, calm landing for courses, workshops and technical tutorials.
It uses numbered lesson cards and enables contextual navigation whenever a lesson
has H2/H3 headings. Content, navigation and optional hero/CTA settings follow the
same contract as the other category themes. Recommended highlighting: `tango`;
alternative: `kate`. No learning-management backend is implied.

```sh
./zeta.sh theme my-site academy tango
```

```powershell
./zeta.ps1 theme my-site academy tango
```

Both commands rebuild the site. Set `homepage.layout: theme` for the designed
landing, or retain `markdown` for a prose-first homepage.
