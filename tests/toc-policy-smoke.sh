#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo 'Pandoc required' >&2; exit 2; }
dir="$(mktemp -d)";trap 'rm -rf -- "$dir"' EXIT
printf '%s\n' '$if(zeta_toc_enabled)$ENABLED$else$DISABLED$endif$: $toc$' > "$dir/t.html"
printf '## One\n\nWords.\n\n## Two\n\nMore words.\n' > "$dir/short.md"
for theme in zen console indie organization aurora paper gazette magazine folio brutalist nocturne liminal reliquary; do
 output="$(pandoc "$dir/short.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M "zeta_toc_theme=$theme" --template="$dir/t.html")"
 case "$theme" in zen|console|indie|organization) [[ "$output" == ENABLED:* ]] ;; *) [[ "$output" == DISABLED:* ]] ;; esac
done
printf '%s\n' '---' 'toc: true' '---' '## Secret room' '' 'Story.' > "$dir/explicit.md"
output="$(pandoc "$dir/explicit.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M zeta_toc_theme=nocturne --template="$dir/t.html")"
[[ "$output" == ENABLED:* && "$output" == *'href="#secret-room"'* ]]
output="$(pandoc "$dir/explicit.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M zeta_toc_theme=zen -M zeta_toc_kind=home --template="$dir/t.html")"
[[ "$output" == DISABLED:* ]]
sed -i 's/toc: true/toc: false/' "$dir/explicit.md"
output="$(pandoc "$dir/explicit.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M zeta_toc_theme=zen --template="$dir/t.html")"
[[ "$output" == DISABLED:* ]]
{
 echo '---';echo 'toc: auto';echo '---'
 for h in One Two Three; do
  printf '\\n## %s\\n\\n' "$h"
  for n in $(seq 1 30); do printf '%s\\n\\n' 'This sample sentence contains many words and belongs to a long structured editorial article.';done
 done
} > "$dir/long.md"
for theme in paper magazine gazette aurora folio;do
 output="$(pandoc "$dir/long.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M "zeta_toc_theme=$theme" --template="$dir/t.html")"
 [[ "$output" == ENABLED:* ]]
done
# Long prose with only two headings must not activate the contextual index.
{ printf '## One\\n\\n';for n in $(seq 1 90);do printf '%s\\n\\n' 'This paragraph contains enough words to make the essay long without introducing additional section headings.';done;printf '## Two\\n\\nRest.'; } > "$dir/two.md"
output="$(pandoc "$dir/two.md" -t html5 --standalone --table-of-contents --lua-filter="$ROOT/templates/common/filters/toc-policy.lua" -M zeta_toc_theme=paper --template="$dir/t.html")"
[[ "$output" == DISABLED:* ]]
echo '[OK] TOC defaults, structural thresholds, overrides and homepage exclusion.'
