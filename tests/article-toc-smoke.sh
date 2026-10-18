#!/usr/bin/env bash
# Verify Pandoc-generated heading links and responsive TOC markup for every theme.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo "Pandoc required" >&2; exit 2; }
SITE="zeta-toc-smoke-$$"
DIR="$ROOT/sites/$SITE"
trap 'rm -rf -- "$DIR"' EXIT
mkdir -p "$DIR/posts"
cat > "$DIR/posts/2026-10-12-index.md" <<'EOF'
---
title: "Article navigation"
date: "2026-10-12"
description: "Navigation regression test"
---
# Intro

Lead-in text.

## Overview

Overview body.

### Details

Details body.

## Closing

Closing body.
EOF
for theme in zen paper console indie organization brutalist folio aurora; do
cat > "$DIR/config.yaml" <<EOF
site:
  title: "Navigation QA"
  description: "TOC checks"
  author: "QA"
  language: "en"
  url: "https://example.org/zeta"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
EOF
 bash "$ROOT/zeta.sh" build "$SITE" >/dev/null
 html="$DIR/public/posts/2026/index.html"
 test -s "$DIR/public/styles/article-toc.css"
 test -s "$DIR/public/assets/zeta-toc.js"
 grep -Fq 'zeta-has-toc' "$html"
 grep -Fq 'class="article-toc"' "$html"
 grep -Fq 'class="zeta-toc-label"' "$html"
 grep -Fq 'href="#overview"' "$html"
 grep -Fq 'href="#details"' "$html"
 grep -Fq 'id="overview"' "$html"
 grep -Fq 'id="details"' "$html"
 grep -Fq 'zeta-toc.js' "$html"
 grep -Fq 'article-toc.css' "$html"
 echo "[OK] $theme article TOC"
done
echo "All theme article indexes passed."
