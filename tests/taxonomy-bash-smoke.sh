#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || exit 2
dir=$(mktemp -d); trap 'rm -rf -- "$dir"' EXIT
mkdir -p "$dir/posts/2026"
for name in one two three; do printf '<html lang="en"><head><title>%s</title></head><body><main><h1>%s</h1></main></body></html>\n' "$name" "$name" > "$dir/posts/2026/$name.html"; done
mkdir -p "$dir/styles"
printf '%s\n' 'body.zeta-static-page{background:#101421}' > "$dir/styles/00-theme-contract.css"
printf '%s\n' 'body.zeta-static-page{display:flex}' > "$dir/styles/zeta-pages.css"
cat > "$dir/index.html" <<'HTML'
<html><head><link rel="stylesheet" href="styles/zeta-pages.css"><link rel="stylesheet" href="styles/00-theme-contract.css"></head><body class="zeta-static-page"><nav aria-label="Primary navigation"><a href="index.html">Home</a> <a href="about/">About</a> <a href="posts.html">Blog</a></nav></body></html>
HTML
printf '<urlset><url><loc>https://example.org/</loc></url></urlset>' > "$dir/sitemap.xml"
printf 'posts/2026/one.html\tcategory\tgodot\tGodot\nposts/2026/one.html\ttag\tplugins\tPlugins\nposts/2026/two.html\tcategory\tgodot\tGodot\nposts/2026/three.html\ttag\tplugins\tPlugins\n' > "$dir/.zeta-taxonomy.tsv"
printf '' | pandoc -f markdown -t plain --lua-filter="$ROOT/templates/common/filters/taxonomies.lua" -M "zeta_taxonomy_output=$dir" -M zeta_taxonomy_url=https://example.org -M 'zeta_taxonomy_title=Demo' -M zeta_taxonomy_language=en -o /dev/null
for page in categories/index.html categories/godot/index.html tags/index.html tags/plugins/index.html; do test -s "$dir/$page"; done
grep -Fq 'href="../../styles/00-theme-contract.css"' "$dir/tags/plugins/index.html"
grep -Fq 'href="../styles/zeta-pages.css"' "$dir/tags/index.html"
grep -Fq 'href="../../about/"' "$dir/tags/plugins/index.html"
grep -Fq 'class="zeta-static-page zeta-tax-page"' "$dir/tags/plugins/index.html"
grep -Fq 'Related articles' "$dir/posts/2026/one.html"
grep -Fq '../../posts/2026/two.html' "$dir/posts/2026/one.html"
grep -Fq 'https://example.org/categories/godot/' "$dir/sitemap.xml"
echo '[OK] Bash taxonomy archives and related articles'
