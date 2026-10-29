#!/usr/bin/env bash
# Theme isolation + Pandoc navigation validation without CI services.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
COMMON="$ROOT/templates/common/styles"
test -s "$COMMON/zeta-navigation.css"
test -s "$COMMON/zeta-pages.css"
if grep -Eq 'zeta-theme-(zen|paper|console|indie|organization|brutalist|folio|aurora)' "$COMMON/zeta-pages.css"; then echo "Unexpected matching content" >&2; exit 1; fi
if grep -Eq 'theme-(zen|paper|console|indie|organization|brutalist|folio|aurora)' "$COMMON/zeta-navigation.css"; then echo "Unexpected matching content" >&2; exit 1; fi
for theme in zen paper console indie organization brutalist folio aurora gazette magazine; do
  css="$ROOT/templates/$theme/styles/00-theme-contract.css"
  test -s "$css"
  for token in --zeta-nav-background --zeta-nav-ink --zeta-nav-current --zeta-nav-type --page-bg --page-fg --page-link; do
    grep -Fq -- "$token" "$css" || { echo "Missing $token in $theme" >&2; exit 1; }
  done
  grep -Fq 'body.zeta-static-page' "$css"
  for kind in index posts article; do
    template="$ROOT/templates/$theme/$kind.html"
    # Pandoc template syntax is intentionally literal.
    # shellcheck disable=SC2016
    grep -Fq '$if(page_navigation)$$page_navigation$$else$' "$template"
  done
  if command -v pandoc >/dev/null 2>&1; then
    html=$(pandoc /dev/null --quiet --from=markdown --to=html5 --standalone \
      --template="$ROOT/templates/$theme/posts.html" \
      -V 'site_lang=en' -V 'site_title=Theme QA' \
      -V 'page_navigation=<a href="./index.html">Home</a><a href="./about/">About</a><a aria-current="page" href="./posts.html">Blog</a>')
    [[ "$html" == *'href="./about/"'* ]]
    [[ "$html" == *'aria-current="page"'* ]]
    [[ "$html" != *'page_navigation'* ]]
  fi
done
echo '[OK] Ten isolated theme contracts and shared navigation.'

# The Aurora backdrop is owned by the page canvas, never the centered content or hero.
aurora_contract="$ROOT/templates/aurora/styles/00-theme-contract.css"
aurora_theme="$ROOT/templates/aurora/styles/theme.css"
grep -Fq -- '--zeta-aurora-page-background:' "$aurora_contract"
grep -Fq 'body.zeta-static-page.zeta-theme-aurora{background-image:var(--zeta-aurora-page-background)}' "$aurora_contract"
grep -Fq 'body.zeta-static-page.zeta-theme-aurora .zeta-content{background:transparent;' "$aurora_contract"
grep -Fq 'background-image:var(--zeta-aurora-page-background)' "$aurora_theme"
grep -Fq '.theme-aurora .hero{position:relative;overflow:hidden;background:transparent}' "$aurora_theme"
echo '[OK] Aurora full-page gradient and transparent content layout.'
