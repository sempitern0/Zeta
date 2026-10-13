# Landing themes · indie and organization

[← All themes](../README.md#five-built-in-themes)

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
