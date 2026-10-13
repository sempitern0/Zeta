#!/usr/bin/env bash
# No-JavaScript multipage smoke test, all eight themes, no blog.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc required' >&2; exit 2; }
name="zeta-pages-test-$$"
dir="$ROOT/sites/$name"
trap 'rm -rf -- "$dir"' EXIT
mkdir -p "$dir/pages" "$dir/posts"
cat > "$dir/pages/index.md" <<'MD'
---
title: "Home"
description: "Static home"
nav: true
nav_order: 0
---
Welcome! [Learn about us](about.md).
MD
cat > "$dir/pages/about.md" <<'MD'
---
title: "About"
description: "An about page"
nav: true
nav_order: 20
---
## Our story

[Return home](index.md#content).
MD
cat > "$dir/pages/draft.md" <<'MD'
---
title: "Draft"
draft: true
---
Not published.
MD
cat > "$dir/posts/2026-10-13-hidden.md" <<'MD'
---
title: "Hidden blog"
date: "2026-10-13"
---
Should not publish.
MD
for theme in zen paper console indie organization brutalist folio aurora; do
cat > "$dir/config.yaml" <<EOF
site:
  title: "Page smoke"
  description: "Test site"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
EOF
 bash "$ROOT/zeta.sh" build "$name" >/dev/null
 test -s "$dir/public/index.html"
 test -s "$dir/public/about/index.html"
 test -s "$dir/public/styles/zeta-pages.css"
 test ! -e "$dir/public/posts.html"
 test ! -e "$dir/public/draft"
 test ! -e "$dir/public/posts/2026/hidden.html"
 grep -Fq 'href="./about/"' "$dir/public/index.html"
 grep -Fq 'href="../index.html#content"' "$dir/public/about/index.html"
 grep -Fq 'https://example.org/about/' "$dir/public/sitemap.xml"
 ! grep -Fq '/posts/' "$dir/public/sitemap.xml"
 echo "[OK] $theme: Markdown pages, links, sitemap, blog disabled"
done
