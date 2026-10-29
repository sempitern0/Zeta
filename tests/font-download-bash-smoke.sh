#!/usr/bin/env bash
# Regression: pinned variable font URLs include literal brackets, which curl must not expand.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
# The downloader only needs the sites module; no network is necessary.
source "$ROOT/lib/bash/sites.sh"
printf 'font fixture\n' > "$tmp/CascadiaCode[wght].ttf"
font_download "file://$tmp/CascadiaCode[wght].ttf" "$tmp/output.ttf"
cmp "$tmp/CascadiaCode[wght].ttf" "$tmp/output.ttf"
printf 'PASS: bracketed variable-font URLs download literally\n'
