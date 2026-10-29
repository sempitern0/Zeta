# Zeta theme catalog

[← Project overview](../README.md) · [Landing configuration](landing-themes.md)

Zeta provides **eight static themes** that work with Bash and PowerShell and share the same Markdown, YAML and template contracts.

| Theme | Visual identity | Use case |
| :-- | :-- | :-- |
| zen | Dark, minimal, developer-friendly | Blogs |
| paper | Light, typographic editorial | Long-form writing |
| console | Monochrome terminal-inspired | Sysadmin / DevOps |
| indie | Game development and release landing | Independent games |
| organization | Open-source identity and resources | Software organizations |
| brutalist | Bold yellow and black, offset graphic cards | Creative studios |
| folio | Soft paper tones, serif type, airy portfolio | Designers and writers |
| aurora | Cinematic gradients, teal accents, modular cards | Digital products |

## Smart code highlighting recommendations

When creating a site, editing its appearance, or switching themes, Zeta recommends a Pandoc syntax-highlighting style matching the theme's **current visual palette**. Recommendations are data-driven and shared by Bash and PowerShell (`templates/common/highlight-recommendations.tsv`). Every suggestion has a rationale and an alternative.

| Theme | Recommended | Alternative | Palette |
| --- | --- | --- | --- |
| zen | breezedark | zenburn | dark slate, cool blue |
| paper | tango | kate | warm paper, rust |
| console | breezedark | zenburn | near-black, green |
| indie | espresso | zenburn | midnight blue, amber |
| organization | tango | kate | pale blue, navy |
| brutalist | kate | monochrome | yellow, black |
| folio | tango | kate | ivory, sage |
| aurora | breezedark | zenburn | navy, teal |
| gazette | tango | kate | newsprint, burgundy |
| magazine | kate | tango | cream, magenta |

The recommended style is the *default*, not a restriction. Zeta checks what the installed Pandoc supports, falls back to an available style where necessary, and offers all available styles in the interactive list. An explicit `theme SITE THEME STYLE` command still uses the supplied style without substitution. No external AI, network service or API key is required.

## Visual theme gallery and open-source fonts

Run `./zeta.sh dashboard` or `.\\zeta.ps1 dashboard`, then open `sites/index.html` (or use the local `serve` command). The workspace includes eight representative, responsive visual samples, even if no site has been created. Samples do not replace real Pandoc builds and do not download fonts, load images or require a framework.

| Theme | Optional coding font | Retained reading / UI font |
| :-- | :-- | :-- |
| zen, aurora | JetBrains Mono | Theme's normal text stack |
| console | Cascadia Code | Terminal-style text stack |
| indie | Fira Code | System sans-serif |
| brutalist | IBM Plex Mono | Bold system sans-serif |
| paper, folio, organization | Source Code Pro | Theme's original serif or system sans-serif |

These coding fonts have open-source licenses. Zeta stores downloaded assets and license texts locally; check upstream licensing before redistributing. Downloading is **optional**, and CSS includes native system fallbacks. Install the suggestion after creating a site:

~~~bash
./zeta.sh fonts my-site recommended
~~~

~~~powershell
.\\zeta.ps1 fonts my-site recommended
~~~

A normal `fonts SITE` command still opens the interactive chooser. The gallery's visual samples use local CSS approximations rather than external webfonts.

## Change a theme

~~~bash
./zeta.sh theme my-site brutalist zenburn
./zeta.sh theme my-site folio zenburn
./zeta.sh theme my-site aurora zenburn
~~~

~~~powershell
.\zeta.ps1 theme my-site brutalist zenburn
.\zeta.ps1 theme my-site folio zenburn
.\zeta.ps1 theme my-site aurora zenburn
~~~

All themes can also be selected in the interactive create wizard. Site Markdown and configuration remain portable between operating systems.

## CSS architecture and browser support

- indie and organization share a scoped CSS foundation in templates/common/styles/landing.css, with individual theme identity tokens. The previous CSS :has() dependency is removed.
- brutalist, folio and aurora share templates/common/styles/catalog.css. Each theme supplies its own fonts, colors and distinctive layout adjustments.
- Traditional flexbox, grid, media queries and keyboard :focus styles are used; no CSS nesting or client-side JavaScript is required.
- Motion preferences are respected and newer layout enhancements have straightforward fallbacks.

The output targets current Chrome/Edge, Firefox and Safari. **Visual browser testing is still required**; Pandoc rendering alone cannot certify cross-browser appearance.

## Content and templates

All eight themes render Markdown articles, code, tables, archives and SEO files. The three new themes also support an optional landing.md introduction. indie and organization additionally support landing.yaml hero artwork and CTAs. See the [landing guide](landing-themes.md).

## Run local tests

~~~bash
bash tests/theme-smoke.sh
bash tests/catalog-smoke.sh
~~~

~~~powershell
.\tests\powershell-build-smoke.ps1
~~~

The tests build all eight themes using Pandoc without running GitHub Actions.

During interactive `create` and interactive theme selection, Zeta asks whether to install the recommended open-source coding font. The default is **No**. Files already present in `.zeta-cache/fonts` are reused before attempting downloads; the site retains its system font fallbacks if the download fails.

## Consistent theme on every page

The selected theme now determines the palette and typography of the Markdown homepage, About, Contact and other static pages as well as the blog. These pages keep one accessible shared HTML shell for navigation and clean URLs, with independent per-theme contracts in `templates/<theme>/styles/00-theme-contract.css`. Both Bash and PowerShell include the selected theme styles in generated HTML; no JavaScript or CSS framework is needed. The static-page shell shares visual identity, but is intentionally not a pixel-identical clone of each theme's dedicated blog landing layout.

To refresh existing sites without deleting content, rebuild them using `./zeta.sh build SITE` or `.\\zeta.ps1 build SITE`. Verify `public/index.html`, `public/about/index.html` and `public/posts.html` together. The local page smoke suites check theme class and stylesheet links for all eight themes.

### Core navigation background token

The common navigation component (`templates/common/styles/zeta-navigation.css`) owns the top-level header surface on Markdown pages, blog archives and articles. A theme may set `--zeta-nav-background` once (for example on `:root` or `body`) to specify its navigation background consistently on every route. Without it, the core falls back to existing palette variables (`--page-panel`, `--surface`, `--panel`, `--bg`) so a new theme does not need route-specific CSS. Existing catalog variants preserve their historical header colors through compatibility tokens. This contract changes only header background color, leaving per-theme typography, responsive sizing and interaction styles intact.

## Theme isolation contract

Each theme owns its palette, typography and visual variants in
`templates/<theme>/styles/00-theme-contract.css`. This file is included
automatically by both native build engines. It must define
`--zeta-nav-background`, `--zeta-nav-ink`, `--zeta-nav-current`
and `--zeta-nav-type` at `:root`, plus scoped Markdown page tokens
`--page-bg`, `--page-panel`, `--page-fg`, `--page-muted`,
`--page-link` and `--page-border` under `body.zeta-static-page`.

For new themes, copy an existing theme folder, update its HTML templates
and CSS, then run the native smoke tests. Do not add theme-specific selectors
to `templates/common/styles/`: the common `zeta-pages.css` owns layout
and `zeta-navigation.css` owns only the top-level navigation. Theme-local CSS
follows common CSS; per-site CSS has final precedence. The Pandoc variable
`page_navigation` is generated once per platform, and templates must
preserve their legacy navigation when that variable is absent.

Validation: `bash tests/theme-isolation-smoke.sh`,
`bash tests/pages-bash-smoke.sh` and
`.\\tests\\pages-powershell-smoke.ps1`. No framework or JavaScript required.

## Taxonomy pages follow the theme

The taxonomy publisher now inherits the ordered local stylesheet links and primary navigation from the already-rendered homepage. Both `tags/` and `categories/`, including nested term pages, rewrite asset and menu links for their output depth. `content-taxonomy.css` provides layout only and inherits foreground, background and accent tokens rather than overriding a site's light/dark appearance. Bash and PowerShell use the same Pandoc Lua filter. Run `bash tests/taxonomy-bash-smoke.sh` or `.\\tests\\taxonomy-powershell-smoke.ps1` to check CSS links, relative paths and navigation.

## Responsive article table of contents

Blog posts use Pandoc's existing `--table-of-contents --toc-depth=3` heading anchors. On wide screens (at least 62rem), Zeta displays the index in a sticky right column while keeping the article text in a readable left column. On narrow screens the index appears before the body, with no horizontal overflow or missing content. Articles with no headings and no Pandoc index retain the original single-column layout.

The shared geometry, nested lists, keyboard focus and active-section state live in `templates/common/styles/article-toc.css`. Each theme customizes only its appearance in `templates/<theme>/styles/article.css`. A small local, deferred `assets/zeta-toc.js` progressively marks the active heading link with `aria-current="location"`; links work normally with JavaScript disabled. None of these assets uses a CDN or external framework. Site-specific `styles/article.css` can override the default.

| Theme | Index treatment |
| --- | --- |
| zen | Dashed developer panel and shell prompt |
| paper | Quiet serif editorial outline |
| console | Terminal read-only index in a framed panel |
| indie | Dark game-dev card |
| organization | Clean documentation navigation |
| brutalist | Yellow box, strong border and offset shadow |
| folio | Airy, restrained serif list |
| aurora | Rounded gradient panel with mint accents |

For regression coverage run `bash tests/article-toc-smoke.sh` (requires Pandoc) and, on Windows, `./tests/powershell-build-smoke.ps1`. Rebuild an existing site to include the new styles and local script.

### Markdown homepage padding

The shared static page shell adds responsive horizontal inset to the generated Markdown page content. This prevents the first heading from touching a full-width theme background or gradient while preserving header alignment. Aurora additionally adjusts vertical spacing in its theme-scoped contract. These spacing rules apply when rebuilding existing sites; no Markdown edits are necessary.
