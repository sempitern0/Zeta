# Landing themes

Zeta supports `indie` (game marketing/devlog) and `organization` (GitHub organization and resources).

## Selecting

```bash
./main.sh theme my-site indie zenburn
./main.sh theme my-site organization zenburn
./main.sh build my-site
```

Both themes use the existing `config.yaml` and Markdown in `posts/` without a JavaScript runtime.

## Optional landing settings

Create `sites/<site>/landing.yaml`:

```yaml
landing:
  eyebrow: "Open-source Godot tools"
  primary_label: "Explore on GitHub"
  primary_url: "https://github.com/Dragonboon"
  secondary_label: "Projects"
  secondary_url: "#updates"
  hero_image: "assets/hero.webp"
  hero_alt: "Promotional artwork"
```

Each field is optional. Put the hero image inside `sites/<site>/assets/`. Images are checked and copied into `public/assets/`. `landing.yaml` survives site-theme edits because it is separate from the main configuration.

Create `sites/<site>/landing.md` containing the game description, features, mission or organizational purpose in Markdown. This displays in the homepage introduction. Neither Markdown nor YAML source gets copied into `public/`.

## Project cards and external URLs

Every Markdown article becomes a card in the landing and archive. To link a repository or external document directly, use frontmatter:

```markdown
---
title: "Nucleus"
description: "Procedural Godot tools."
date: "2026-10-12"
external_url: "https://github.com/Dragonboon/Nucleus"
---

# Nucleus

Documentation and project details.
```

Without `external_url`, the card links to its generated HTML article. With it, the card links to the external resource but the local article is still built and included in the sitemap. Unsafe link schemes are rejected.

## Notes

Both themes are responsive, offer keyboard focus and skip links, and support reduced motion. Repository descriptions are maintained in Markdown; there is no live GitHub API dependency. Deploy only the generated `public/` directory.