#!/usr/bin/env bash
# Local regression across all eight themes. Does not invoke GitHub Actions.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo "Pandoc required" >&2; exit 2; }
SITE="zeta-catalog-smoke-$$"
DIR="${ROOT}/sites/${SITE}"
trap 'rm -rf -- "$DIR"' EXIT
mkdir -p "$DIR/posts"
cat > "$DIR/posts/2026-10-12-demo.md" <<'EOF'
---
title: "Catalog Example"
date: "2026-10-12"
description: "Tables and code."
author: "QA"
tags: [zeta, catalog]
---
# Example article

Use **Markdown** everywhere.

| Browser | Output |
| --- | --- |
| Firefox | HTML |
| Chromium | HTML |
EOF
printf '## About this project\n\nMade with **Zeta**.\n' > "$DIR/landing.md"
for theme in zen paper console indie organization brutalist folio aurora; do
cat > "$DIR/config.yaml" <<EOF
site:
  title: "Catalog Smoke"
  description: "Theme $theme"
  author: "Zeta QA"
  language: "en"
  url: "https://example.org/catalog"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
EOF
 bash "$ROOT/zeta.sh" build "$SITE" >/dev/null
 for file in index.html posts.html posts/2026/demo.html robots.txt sitemap.xml styles/normalize.css styles/markdown.css; do
  [[ -s "$DIR/public/$file" ]] || { echo "$theme missing $file" >&2; exit 1; }
 done
 grep -Fq 'Catalog Example' "$DIR/public/posts/2026/demo.html"
 grep -Fq '<html lang="en">' "$DIR/public/index.html"
 case "$theme" in
  brutalist|folio|aurora)
   [[ -s "$DIR/public/styles/catalog.css" && -s "$DIR/public/styles/theme.css" ]]
   grep -Fq "theme-$theme" "$DIR/public/index.html"
   grep -Fq 'About this project' "$DIR/public/index.html"
   ;;
  indie|organization)
   [[ -s "$DIR/public/styles/landing.css" ]]
   grep -Fq 'About this project' "$DIR/public/index.html"
   ;;
 esac
 echo "[OK] $theme"
done
echo "All eight themes passed."
