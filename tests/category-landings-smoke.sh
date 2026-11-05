#!/usr/bin/env bash
# Validate themed homepage for the six categories with real Pandoc builds.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc required' >&2; exit 2; }
name="zeta-category-$$"; site="$ROOT/sites/$name"
trap 'rm -rf -- "$site"' EXIT
mkdir -p "$site/pages" "$site/posts"
cat > "$site/pages/index.md" <<'MD'
---
title: Home
nav: true
---
# Markdown homepage marker
MD
cat > "$site/pages/about.md" <<'MD'
---
title: About
nav: true
---
# About page marker
MD
for theme in music cuisine spirituality photography store services academy; do
cat > "$site/config.yaml" <<YAML
site:
  title: "Category demo"
  description: "A sample landing"
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
homepage:
  layout: theme
  show_posts: false
YAML
 bash "$ROOT/zeta.sh" build "$name" >/dev/null
 index="$site/public/index.html"
 grep -Fq "theme-$theme" "$index"
 grep -Fq 'href="./about/"' "$index"
 grep -Fq 'About page marker' "$site/public/about/index.html"
 if grep -Fq 'Markdown homepage marker' "$index"; then echo "Markdown replaced themed homepage: $theme" >&2; exit 1; fi
 test ! -e "$site/public/posts.html"
 grep -Fq 'styles/landing.css' "$index"
 grep -Fq 'styles/00-theme-contract.css' "$site/public/about/index.html"
 grep -Fq 'Markdown homepage marker' "$site/pages/index.md"
 echo "[OK] $theme category landing"
done
sed -i 's/layout: theme/layout: markdown/' "$site/config.yaml"
bash "$ROOT/zeta.sh" build "$name" >/dev/null
grep -Fq 'Markdown homepage marker' "$site/public/index.html"
sed -i 's/layout: markdown/layout: invalid/' "$site/config.yaml"
if bash "$ROOT/zeta.sh" build "$name" >/dev/null 2>&1; then echo 'Invalid layout accepted' >&2; exit 1; fi
echo '[OK] Layout fallback and validation'
