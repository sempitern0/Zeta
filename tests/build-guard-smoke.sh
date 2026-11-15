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
