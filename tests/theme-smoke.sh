#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="zeta-theme-smoke-$$"
DIR="$ROOT/sites/$SITE"
trap 'rm -rf -- "$DIR"' EXIT
mkdir -p "$DIR/posts" "$DIR/assets"
cat > "$DIR/config.yaml" <<'EOF'
site:
  title: "Smoke Test"
  description: "An example organization"
  author: "QA"
  language: "en"
  url: "https://example.org/zeta"
theme:
  name: "indie"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
EOF
cat > "$DIR/landing.yaml" <<'EOF'
landing:
  eyebrow: "Made with care"
  primary_url: "https://github.com/example/test?a=1&b=2"
  hero_image: "assets/hero.svg"
  hero_alt: "Example illustration"
EOF
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><rect width="20" height="20"/></svg>' > "$DIR/assets/hero.svg"
printf '%s\n' '## Our mission' '' 'Build **useful tools**.' > "$DIR/landing.md"
cat > "$DIR/posts/2026-10-12-example.md" <<'EOF'
---
title: "First project"
description: "An example repository."
date: "2026-10-12"
external_url: "https://github.com/example/test"
---
# First project
Some documentation.
EOF
bash "$ROOT/main.sh" build "$SITE" >/dev/null
for f in index.html posts.html posts/2026/example.html assets/hero.svg styles/theme.css styles/article.css sitemap.xml; do test -f "$DIR/public/$f"; done
grep -Fq 'rel="canonical" href="https://example.org/zeta/"' "$DIR/public/index.html"
grep -Fq 'og:type" content="website"' "$DIR/public/index.html"
grep -Fq 'rel="canonical" href="https://example.org/zeta/posts/2026/example.html"' "$DIR/public/posts/2026/example.html"
test "$(grep -c 'rel="canonical"' "$DIR/public/index.html")" -eq 1
test "$(grep -c 'name="description"' "$DIR/public/index.html")" -eq 1
grep -Fq 'Our mission' "$DIR/public/index.html"
grep -Fq 'href="https://github.com/example/test"' "$DIR/public/posts.html"
grep -Fq 'https://github.com/example/test?a=1&amp;b=2' "$DIR/public/index.html"
bash "$ROOT/main.sh" theme "$SITE" organization zenburn >/dev/null
grep -Fq 'Our mission' "$DIR/public/index.html"
grep -Fq 'href="https://github.com/example/test"' "$DIR/public/index.html"
sed -i 's|https://github.com/example/test?a=1&b=2|javascript:alert(1)|' "$DIR/landing.yaml"
if bash "$ROOT/main.sh" build "$SITE" >/dev/null 2>&1; then echo "Unsafe URL accepted" >&2; exit 1; fi
grep -Fq 'Our mission' "$DIR/public/index.html"
echo "Theme smoke tests passed."