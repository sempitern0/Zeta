#!/usr/bin/env bash
# Regression: only manual edits to generated public/ need confirmation.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
msg_warn() { printf 'WARN %s\n' "$*" >&2; }
msg_error() { printf 'ERROR %s\n' "$*" >&2; }
# shellcheck source=../lib/bash/build-guard.sh
source "$ROOT/lib/bash/build-guard.sh"
mkdir -p "$tmp/public/styles"
echo 'original' > "$tmp/public/styles/theme.css"
echo '<p>original</p>' > "$tmp/public/index.html"
zeta_build_manifest "$tmp/public" "$tmp/.zeta-build-manifest.tsv"
FORCE=false
zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"
test -s "$tmp/probe"
echo 'edited' > "$tmp/public/styles/theme.css"
if zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"; then
  echo "Modified CSS was not protected" >&2; exit 1
fi
grep -Fq edited "$tmp/public/styles/theme.css"
FORCE=true
zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"
FORCE=false
echo 'original' > "$tmp/public/styles/theme.css"
echo custom > "$tmp/public/custom.txt"
if zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"; then
  echo "Untracked file was not protected" >&2; exit 1
fi
rm "$tmp/public/custom.txt"
rm "$tmp/public/index.html"
if zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"; then
  echo "Deleted generated file was not detected" >&2; exit 1
fi
echo '<p>original</p>' > "$tmp/public/index.html"
rm "$tmp/.zeta-build-manifest.tsv"
if zeta_build_output_guard "$tmp/public" "$tmp/.zeta-build-manifest.tsv" test "$tmp/probe"; then
  echo "Unverified legacy output was not protected" >&2; exit 1
fi
echo '[OK] Bash guard: clean build, edited, untracked, deleted, legacy and force.'

# End-to-end: regular source changes compile, while public edits block publication.
site="zeta-build-guard-$$"
site_dir="$ROOT/sites/$site"
trap 'rm -rf -- "$tmp" "$site_dir"' EXIT
mkdir -p "$site_dir/pages" "$site_dir/posts" "$site_dir/styles"
cat > "$site_dir/config.yaml" <<'YAML'
site:
  title: "Guard Test"
  description: "Output integrity regression"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "console"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
YAML
printf '# First content\n' > "$site_dir/pages/index.md"
bash "$ROOT/zeta.sh" build "$site" >/dev/null
test -s "$site_dir/.zeta-build-manifest.tsv"
printf '# New content\n' > "$site_dir/pages/index.md"
bash "$ROOT/zeta.sh" build "$site" >/dev/null
grep -Fq 'New content' "$site_dir/public/index.html"
printf '/* handwritten edit */\n' >> "$site_dir/public/styles/normalize.css"
if bash "$ROOT/zeta.sh" build "$site" >/dev/null 2>&1; then
  echo "Rebuild silently replaced hand-edited public CSS" >&2; exit 1
fi
grep -Fq 'handwritten edit' "$site_dir/public/styles/normalize.css"
bash "$ROOT/zeta.sh" --force build "$site" >/dev/null
if grep -Fq 'handwritten edit' "$site_dir/public/styles/normalize.css"; then
  echo "Forced build failed to regenerate the output CSS" >&2; exit 1
fi
printf 'body{outline:0}\n' > "$site_dir/styles/custom.css"
bash "$ROOT/zeta.sh" build "$site" >/dev/null
test -s "$site_dir/public/styles/custom.css"
grep -Fq 'outline:0' "$site_dir/public/styles/custom.css"
echo '[OK] End-to-end: build, source update, blocked output edit, force and site CSS.'
