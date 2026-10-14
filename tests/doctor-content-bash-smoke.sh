#!/usr/bin/env bash
# Read-only local source diagnostics: invalid frontmatter and missing links.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v pandoc >/dev/null || { echo "Pandoc is required" >&2; exit 2; }
site="zeta-doctor-content-$$"
root="$ROOT/sites/$site"
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/pages" "$root/posts"
cat > "$root/config.yaml" <<'YAML'
site:
  title: "Doctor smoke"
  description: "Content diagnostics"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
YAML
cat > "$root/pages/index.md" <<'MD'
---
title: "Home"
description: "Valid metadata"
---
[Missing](absent.md)

![no file](../assets/missing.png)

[](javascript:alert)
MD
if bash "$ROOT/zeta.sh" doctor "$site" > "$root/report.txt" 2>&1; then
 echo "Doctor failed to detect broken links" >&2; exit 1
fi
grep -Fq 'BROKEN_LINK' "$root/report.txt"
grep -Fq 'MISSING_IMAGE' "$root/report.txt"
grep -Fq 'UNSAFE_URL' "$root/report.txt"
cat > "$root/pages/index.md" <<'MD'
---
title: ""Broken""
---
Content
MD
if bash "$ROOT/zeta.sh" doctor "$site" > "$root/report.txt" 2>&1; then
 echo "Doctor failed to detect malformed YAML" >&2; exit 1
fi
grep -Fq 'Markdown parse' "$root/report.txt"
echo "[OK] Bash Doctor recognizes broken sources without modifying them."
