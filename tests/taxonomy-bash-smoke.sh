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

# Regression: sites with exclusively tags OR categories must not link to the
# archive that was not generated. Run Doctor against the resulting HTML too.
for kind in tag category; do
  if [[ "$kind" == tag ]]; then folder=tags; missing=categories; else folder=categories; missing=tags; fi
  fixture="$dir/$kind-only"
  mkdir -p "$fixture/posts/2026" "$fixture/styles"
  cp "$dir/styles/"*.css "$fixture/styles/"
  cat > "$fixture/index.html" <<'HTML'
<!doctype html><html lang="en"><head><title>Fixture</title><meta name="description" content="Fixture"><link rel="canonical" href="https://example.org/"><link rel="stylesheet" href="styles/zeta-pages.css"><link rel="stylesheet" href="styles/00-theme-contract.css"></head><body><nav aria-label="Primary navigation"><a href="index.html">Home</a></nav></body></html>
HTML
  cat > "$fixture/posts/2026/one.html" <<'HTML'
<!doctype html><html lang="en"><head><title>One</title><meta name="description" content="One"><link rel="canonical" href="https://example.org/posts/2026/one.html"></head><body><main><h1>One</h1></main></body></html>
HTML
  printf '<urlset><url><loc>https://example.org/</loc></url><url><loc>https://example.org/posts/2026/one.html</loc></url></urlset>\n' > "$fixture/sitemap.xml"
  printf 'posts/2026/one.html\t%s\tonly\tOnly\n' "$kind" > "$fixture/.zeta-taxonomy.tsv"
  printf '' | pandoc -f markdown -t plain --lua-filter="$ROOT/templates/common/filters/taxonomies.lua" -M "zeta_taxonomy_output=$fixture" -M zeta_taxonomy_url=https://example.org -M 'zeta_taxonomy_title=Fixture' -M zeta_taxonomy_language=en -o /dev/null
  test -s "$fixture/$folder/index.html"
  test -s "$fixture/$folder/only/index.html"
  test ! -e "$fixture/$missing/index.html"
  if grep -Fq "$missing/" "$fixture/$folder/index.html" "$fixture/$folder/only/index.html"; then
    echo "Navigation points to nonexistent $missing archive in $kind-only site" >&2; exit 1
  fi
  printf '' | pandoc -f markdown -t plain --lua-filter="$ROOT/templates/common/filters/doctor-public.lua" -M "zeta_doctor_output=$fixture" -M zeta_doctor_url=https://example.org -o /dev/null 2> "$fixture/doctor.log"
  if grep -Fq 'ZETA_DOCTOR|FAIL|BROKEN_OUTPUT_LINK|' "$fixture/doctor.log"; then
    echo "Doctor detected broken links in $kind-only taxonomy site" >&2
    cat "$fixture/doctor.log" >&2
    exit 1
  fi
done

echo '[OK] Bash taxonomy archives, optional kinds and related articles'
