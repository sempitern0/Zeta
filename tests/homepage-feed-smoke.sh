#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
name="zeta-homepage-$$"
site="$ROOT/sites/$name"
trap 'rm -rf -- "$site"' EXIT
mkdir -p "$site/posts" "$site/pages"
cat > "$site/config.yaml" <<'YAML'
site:
  title: "Editorial test"
  description: "Test excerpts"
  author: "Editorial desk"
  language: "en"
  url: "https://example.org"
theme:
  name: "paper"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: true
homepage:
  show_posts: true
  posts_limit: 1
YAML
cat > "$site/pages/index.md" <<'MD'
---
title: "Editorial home"
description: "An editorial homepage"
---
# Home editorial introduction

Keep this Markdown text on the homepage.
MD
for item in one two; do
cat > "$site/posts/2026-10-20-$item.md" <<EOF
---
title: "Headline $item"
date: "2026-10-20"
description: "Summary $item"
author: "Editorial desk"
---
# Article $item
EOF
done
for theme in zen paper console indie organization brutalist folio aurora gazette magazine; do
  sed -i "s/^  name: .*/  name: \"$theme\"/" "$site/config.yaml"
  bash "$ROOT/zeta.sh" build "$name" >/dev/null
  index="$site/public/index.html"
  grep -Fq 'Keep this Markdown text' "$index"
  grep -Fq 'zeta-home-feed' "$index"
  grep -Fq 'Headline ' "$index"
  test "$(grep -o 'class="zeta-home-story"' "$index" | wc -l)" -eq 1
  grep -Fq 'href="posts/2026/' "$index"
  test -f "$site/public/posts.html"
  if grep -Fq 'ZETA_HOME_FEED_SLOT' "$index"; then echo "Marker leak in $theme"; exit 1; fi
done
sed -i 's/show_posts: true/show_posts: false/' "$site/config.yaml"
bash "$ROOT/zeta.sh" build "$name" >/dev/null
if grep -Fq 'zeta-home-feed' "$site/public/index.html"; then echo 'False option ignored'; exit 1; fi
sed -i 's/show_posts: false/show_posts: auto/' "$site/config.yaml"
sed -i 's/name: "magazine"/name: "paper"/' "$site/config.yaml"
bash "$ROOT/zeta.sh" build "$name" >/dev/null
grep -Fq 'zeta-home-feed' "$site/public/index.html"
sed -i 's/blog: true/blog: false/' "$site/config.yaml"
bash "$ROOT/zeta.sh" build "$name" >/dev/null
if grep -Fq 'zeta-home-feed' "$site/public/index.html"; then echo 'Disabled blog leak'; exit 1; fi
echo '[OK] Ten theme homepage feeds: enabled, disabled, limit, blog-free'
