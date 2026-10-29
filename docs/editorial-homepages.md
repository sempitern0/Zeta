# Editorial homepages and article feeds

Zeta supports an optional **recent articles** section directly on the Markdown homepage (`pages/index.md`) in every theme. The content of that Markdown page is preserved; the list is generated in the build from already-compiled articles and uses the theme's colors.

Configure with either interactive Zeta assistant: **Manage site → Homepage articles**. Or run:

```powershell
.\zeta.ps1 homepage triangulo-digital true 6
.\zeta.ps1 build triangulo-digital
.\zeta.ps1 doctor triangulo-digital
```

```bash
./zeta.sh homepage my-site true 6
./zeta.sh build my-site
./zeta.sh doctor my-site
```

The site configuration contains:

```yaml
homepage:
  show_posts: auto # auto, true, false
  posts_limit: 6   # 1..30
```

- `auto` (default when unspecified) shows the post feed for **paper**, **gazette** and **magazine**, and leaves other themes' Markdown homepages minimal.
- `true` enables the section for **all themes**, preserving the original Markdown introduction and navigation.
- `false` disables the section.
- If `build.blog: false`, the feed is always disabled, even if `show_posts: true`.
- The archive remains available at `posts.html` when the blog is enabled.
- Classic sites without `pages/index.md` continue to use their theme's original homepage.

## Themes for publications

**Paper** now displays a first-page newspaper layout on Markdown-driven sites: one dominant lead article and compact secondary stories.

**Gazette** is a classic broadsheet: high-contrast ink, large masthead, multi-column hierarchy and minimal embellishment.

**Magazine** is a contemporary editorial design: oversized headlines, vivid contrast, generous whitespace and modular article cards.

The other eight original themes remain supported. All ten themes expose the same `homepage.show_posts` setting; they use their own color tokens and typography without introducing external fonts, JavaScript frameworks or an extra build dependency.

This section uses the existing `public/posts/YYYY/slug.html` articles and snippets, preserving escape-handling and links. The homepage feed is injected into the build's staging output before sitemap/SEO finalization; generated-only files are discarded, and originals under `pages/` and `posts/` are never rewritten.
