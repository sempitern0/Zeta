#!/usr/bin/env bash
# Run from the Zeta repository after extracting this patch.
# All fixtures are temporary: no sites/ changes, network access or Actions.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc is required' >&2; exit 2; }
for lua in "$ROOT"/templates/common/filters/*.lua; do
  pandoc lua -e "assert(loadfile([[$lua]]))" >/dev/null
done
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/styles" "$work/tags/plugins"
printf '%s\n' 'body.zeta-static-page{display:flex}' > "$work/styles/zeta-pages.css"
printf '%s\n' 'body.zeta-static-page{--page-bg:#101421}' > "$work/styles/00-theme-contract.css"
cat > "$work/index.html" <<'HTML'
<!doctype html><html lang="en"><head><title>Home</title><meta name="description" content="Home"><link rel="canonical" href="https://example.org/"><link rel="stylesheet" href="styles/zeta-pages.css"><link href="styles/00-theme-contract.css" rel="stylesheet"></head><body class="zeta-static-page"><main>Home</main></body></html>
HTML
cat > "$work/tags/plugins/index.html" <<'HTML'
<!doctype html><html lang="en"><head><title>Plugins</title><meta name="description" content="Posts about plugins"><link rel="canonical" href="https://example.org/tags/plugins/"><link rel="stylesheet" href="../../styles/zeta-pages.css"><link rel="stylesheet" href="../../styles/00-theme-contract.css"></head><body class="zeta-static-page zeta-tax-page"><main>Plugins</main></body></html>
HTML
printf '<urlset><url><loc>https://example.org/</loc></url><url><loc>https://example.org/tags/plugins/</loc></url></urlset>\n' > "$work/sitemap.xml"
run_doctor() {
  printf '' | pandoc -f markdown -t plain -o /dev/null \
    --lua-filter="$ROOT/templates/common/filters/doctor-public.lua" \
    -M "zeta_doctor_output=$work" -M zeta_doctor_url=https://example.org 2>&1
}
report="$(run_doctor)"
grep -Fq 'ZETA_DOCTOR|OK|OUTPUT_CHECKED|2 HTML file(s) inspected' <<< "$report"
if grep -q 'ZETA_DOCTOR|FAIL|' <<< "$report"; then printf '%s\n' "$report"; exit 1; fi
archive_original="$(cat "$work/tags/plugins/index.html")"
# CSS missing from otherwise valid HTML must be reported, not silently accepted.
sed -i 's@<link rel="stylesheet" href="../../styles/00-theme-contract.css">@@' "$work/tags/plugins/index.html"
report="$(run_doctor)"
grep -Fq 'ZETA_DOCTOR|FAIL|THEME_STYLES|tags/plugins/index.html: missing stylesheet styles/00-theme-contract.css' <<< "$report"
# A CSS reference can be present yet broken because of incorrect depth.
printf '%s\n' "$archive_original" > "$work/tags/plugins/index.html"
sed -i 's@href="../../styles/00-theme-contract.css"@href="../styles/00-theme-contract.css"@' "$work/tags/plugins/index.html"
report="$(run_doctor)"
grep -Fq 'ZETA_DOCTOR|FAIL|BROKEN_OUTPUT_LINK' <<< "$report"
grep -Fq 'ZETA_DOCTOR|FAIL|THEME_STYLES' <<< "$report"
echo '[OK] Lua syntax + stylesheet presence and relative-path validation.'
