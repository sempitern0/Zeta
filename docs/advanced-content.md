# Advanced content management

Zeta automatically converts article metadata into static category and tag archives, without JavaScript or a server-side runtime.

## Authoring metadata

In an article in your site's posts directory:

~~~yaml
---
title: "Godot plugins for puzzle games"
description: "A collection of techniques for implementing plugins."
date: "2026-10-14"
category: "Godot"
tags: [plugins, puzzles, tools]
---

## Introduction

Your Markdown article goes here.
~~~

Category is an optional single classification. Tags are optional multiple labels, expressed as a Markdown YAML list or comma-separated flow list. When creating a post interactively, both Bash and PowerShell now ask for the category and tags.

Category/tag names are turned into lowercase URL-safe slugs. If two different labels would generate the same slug (for example, \`Godot\` and \`godot\`), the build fails with a clear collision instead of publishing confusing duplicate pages. Edit the labels so they match exactly.

## Generated static structure

A blog with the metadata above builds:

~~~text
public/
├── posts/2026/<article>.html
├── categories/
│   ├── index.html             # Category directory
│   └── godot/index.html       # Articles filed under Godot
├── tags/
│   ├── index.html             # Tag directory
│   ├── plugins/index.html
│   ├── puzzles/index.html
│   └── tools/index.html
├── styles/content-taxonomy.css
└── sitemap.xml
~~~

Each article gets a navigation section with clickable categories/tags and up to three related articles. Relatedness is based on shared categories and tags. Articles with no taxonomy metadata are still published normally. Sites without a blog do not produce taxonomy archives.

The generated archives have semantic HTML, keyboard navigation, focus indicators, responsive CSS and no client-side JavaScript. Their routes are added to the sitemap and then processed by Zeta's shared SEO and Schema.org generation stages.

## Build workflow

1. Markdown posts are rendered as ordinary articles.
2. The Bash or PowerShell engine extracts normalized category/tag assignments into a temporary TSV manifest in the staged output directory.
3. The shared Pandoc Lua filter, \`templates/common/filters/taxonomies.lua\`, generates static archives, related links and sitemap entries.
4. The shared SEO and publishing processors then handle every generated HTML page.
5. The temporary manifest is removed before the staged output replaces \`public/\`.

Collisions with existing authored \`categories/\` or \`tags/\` pages cause the build to fail rather than overwriting manually authored content.

## Local tests

~~~bash
bash tests/taxonomy-bash-smoke.sh
bash tests/theme-smoke.sh
~~~

~~~powershell
.\tests\taxonomy-powershell-smoke.ps1
.\tests\powershell-build-smoke.ps1
~~~

The smoke tests do not run GitHub Actions. Pandoc is the only additional tool needed to run the shared taxonomy processor.

## Future work

Hierarchical documentation navigation, automatic breadcrumb trails for arbitrarily nested Markdown pages, taxonomy management commands, and page rename/refactor operations remain separate enhancements. This iteration focuses on static post discovery.
