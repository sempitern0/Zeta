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
