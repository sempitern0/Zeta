#!/usr/bin/env bash
# Horror themes must be structurally distinct, readable and free from TOC spoilers.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc required' >&2; exit 2; }
SITE="zeta-horror-reading-$$"
DIR="$ROOT/sites/$SITE"
trap 'rm -rf -- "$DIR"' EXIT
mkdir -p "$DIR/posts"
cat > "$DIR/posts/2026-11-01-test.md" <<'MD'
---
title: "The Room Beyond"
date: "2026-11-01"
description: "A long-form chapter with its own secret headings."
author: "QA"
tags: [horror, mystery]
---
The first door was locked.

## The unseen second room

This heading must appear in the prose flow, not in a sidebar.

### A voice behind the wall

And no one answered.
MD
for theme in nocturne liminal reliquary; do
 cat > "$DIR/config.yaml" <<EOF
site:
  title: "The Archive"
  description: "An anthology of unsettling stories"
  author: "QA"
  language: "en"
  url: "https://example.org/"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
EOF
 bash "$ROOT/zeta.sh" build "$SITE" >/dev/null
 article="$DIR/public/posts/2026/test.html"
 for page in index.html posts.html posts/2026/test.html; do
  test -s "$DIR/public/$page" || { echo "Missing $theme/$page" >&2; exit 1; }
 done
 for css in styles/00-theme-contract.css styles/theme.css styles/article.css; do
  test -s "$DIR/public/$css" || { echo "Missing $theme/$css" >&2; exit 1; }
 done
 grep -Fq "theme-$theme" "$article"
 grep -Fq 'id="the-unseen-second-room"' "$article"
 grep -Fq 'id="a-voice-behind-the-wall"' "$article"
 if grep -Eq 'article-toc|zeta-has-toc|zeta-toc.js|href="#the-unseen-second-room"' "$article"; then
  echo "Unexpected TOC / section observer in $theme article" >&2
  exit 1
 fi
 if grep -Fq '$body$' "$article"; then echo "Unexpanded template content in $theme" >&2; exit 1; fi
 case "$theme" in
  nocturne) grep -Fq 'night-manuscript' "$article";grep -Fq 'night-entrance' "$DIR/public/index.html";;
  liminal) grep -Fq 'liminal-room' "$article";grep -Fq 'liminal-door' "$DIR/public/index.html";;
  reliquary) grep -Fq 'reliquary-folio' "$article";grep -Fq 'reliquary-inner' "$DIR/public/index.html";;
 esac
 # Regression: prose is constrained independently of its decorative container.
 case "$theme" in
  nocturne)
   grep -Fq 'max-width:57ch;margin-inline:auto;text-align:left;font:1.15rem/1.8' "$DIR/public/styles/theme.css"
   grep -Fq 'max-width:57ch;margin-inline:auto;text-align:left;font-size:1.15rem;line-height:1.8' "$DIR/public/styles/00-theme-contract.css"
   ;;
  liminal)
   grep -Fq 'max-width:58ch;margin-inline:auto;text-align:left;font:1.1rem/1.76' "$DIR/public/styles/theme.css"
   grep -Fq 'max-width:58ch;margin-inline:auto;text-align:left;font-size:1.1rem;line-height:1.76' "$DIR/public/styles/00-theme-contract.css"
   ;;
  reliquary)
   grep -Fq 'width:100%;max-width:54rem' "$DIR/public/styles/theme.css"
   grep -Fq 'max-width:56ch;margin-inline:auto;text-align:left;font:1.17rem/1.8' "$DIR/public/styles/theme.css"
   grep -Fq 'max-width:56ch;margin-inline:auto;text-align:left;font-size:1.17rem;line-height:1.8' "$DIR/public/styles/00-theme-contract.css"
   ;;
 esac
 echo "[OK] $theme: unique composition; focused prose width; no TOC"
done
