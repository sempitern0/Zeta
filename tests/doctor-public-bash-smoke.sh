#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || exit 2
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/about"
cat > "$tmp/index.html" <<'HTML'
<html lang="en"><head><title>Home</title><meta name="description" content="Home"><link rel="canonical" href="https://example.org/"></head><body><a href="about/">About</a></body></html>
HTML
cat > "$tmp/about/index.html" <<'HTML'
<html lang="en"><head><title>About</title><meta name="description" content="About"><link rel="canonical" href="https://example.org/about/"></head><body><a href="../index.html">Home</a></body></html>
HTML
printf '<urlset><url><loc>https://example.org/</loc></url><url><loc>https://example.org/about/</loc></url></urlset>' > "$tmp/sitemap.xml"
run() { printf '' | pandoc --lua-filter="$ROOT/templates/common/filters/doctor-public.lua" -f markdown -t plain -o /dev/null -M "zeta_doctor_output=$tmp" -M zeta_doctor_url=https://example.org 2>&1; }
run | grep -F 'OUTPUT_CHECKED'
sed -i 's@href="about/"@href="missing/"@' "$tmp/index.html"
run | grep -F 'BROKEN_OUTPUT_LINK'
sed -i 's@href="missing/"@href="about/"@' "$tmp/index.html"
sed -i 's@https://example.org/about/@https://example.org/wrong/@' "$tmp/about/index.html"
run | grep -F 'CANONICAL'
sed -i 's@https://example.org/wrong/@https://example.org/about/@' "$tmp/about/index.html"
sed -i 's#</urlset>#<url><loc>https://example.org/missing/</loc></url></urlset>#' "$tmp/sitemap.xml"
run | grep -F 'SITEMAP_MISSING'
echo '[OK] Bash published HTML Doctor filter'
