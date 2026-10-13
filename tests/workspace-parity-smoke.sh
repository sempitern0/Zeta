#!/usr/bin/env bash
# End-to-end: use the Bash wizard, parse both examples, build and inspect dashboard.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo "Pandoc required" >&2; exit 2; }
site="zeta-visual-smoke-$$"
site_dir="${ROOT}/sites/${site}"
trap 'rm -rf -- "$site_dir"; bash "$ROOT/zeta.sh" dashboard >/dev/null 2>&1 || true' EXIT
printf 'Visual smoke\nAccessibility and HTML\nQA\nen\n%s\nhttps://example.org\nzen\nzenburn\n' "$site" | bash "$ROOT/zeta.sh" create >/dev/null
for sample in markdown-showcase code-showcase; do
 file="$site_dir/posts/$(date +%Y-%m-%d)-zeta-$sample.md"
 test -s "$file" || { echo "Missing example: $sample" >&2; exit 1; }
 pandoc -f markdown -t html -o /dev/null "$file"
done
bash "$ROOT/zeta.sh" build "$site" >/dev/null
bash "$ROOT/zeta.sh" dashboard >/dev/null
test -s "$site_dir/public/index.html"
test -s "$ROOT/sites/workspace.css"
grep -Fq 'Zeta local workspace' "$ROOT/sites/index.html"
grep -Fq 'Visual smoke' "$ROOT/sites/index.html"
grep -Fq 'Ready' "$ROOT/sites/index.html"
grep -Fq 'Accessibility and HTML' "$ROOT/sites/index.html"
echo '[OK] Bash shared examples and workspace dashboard.'
