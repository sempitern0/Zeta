#!/usr/bin/env bash
# Shared SEO filter regression; no hosting services or GitHub Actions needed.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc required' >&2; exit 2; }
stage=$(mktemp -d); trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/about" "$stage/posts/2026" "$stage/assets"
cat > "$stage/index.html" <<'HTML'
<!doctype html><html lang="en"><head><title>Example &amp; Zeta</title><meta name="description" content="Homepage"><meta name="description" content="duplicate"><link rel="canonical" href="https://old.example/"></head><body>Home</body></html>
HTML
cat > "$stage/about/index.html" <<'HTML'
<!doctype html><html lang="en"><head><title>About</title></head><body>About</body></html>
HTML
cat > "$stage/posts/2026/first.html" <<'HTML'
<!doctype html><html lang="en"><head><title>First article</title><meta name="description" content="Individual summary"></head><body><time datetime="2026-10-14">14 October</time></body></html>
HTML
printf '<svg xmlns="http://www.w3.org/2000/svg"></svg>\n' > "$stage/assets/cover.svg"
render() {
 printf '' | pandoc -f markdown -t plain --lua-filter="$ROOT/templates/common/filters/seo-publish.lua" \
 -M "zeta_seo_output=$stage" -M zeta_seo_url=https://example.org/project \
 -M "zeta_seo_title=Test site" -M "zeta_seo_description=Site description" \
 -M zeta_seo_image=assets/cover.svg -o /dev/null
}
render
grep -Fq 'href="https://example.org/project/"' "$stage/index.html"
grep -Fq 'href="https://example.org/project/about/"' "$stage/about/index.html"
grep -Fq 'href="https://example.org/project/posts/2026/first.html"' "$stage/posts/2026/first.html"
grep -Fq 'content="summary_large_image"' "$stage/index.html"
grep -Fq 'content="https://example.org/project/assets/cover.svg"' "$stage/index.html"
grep -Fq 'article:published_time" content="2026-10-14"' "$stage/posts/2026/first.html"
grep -Fq 'og:title" content="Example &amp; Zeta"' "$stage/index.html"
test "$(grep -c 'name="description"' "$stage/index.html")" -eq 1
test "$(grep -c 'rel="canonical"' "$stage/index.html")" -eq 1
before=$(sha256sum "$stage/index.html" | cut -d ' ' -f 1)
render
test "$(sha256sum "$stage/index.html" | cut -d ' ' -f 1)" = "$before"
echo '[OK] Bash SEO filter: canonical, social preview, article date and idempotence'
