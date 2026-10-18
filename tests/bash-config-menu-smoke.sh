#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cat > "$tmp/config.yaml" <<'EOF'
site:
  title: "Example"
  image: "assets/cover.webp"
  custom: "preserved"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
  extra: "untouched"
build:
  blog: false
  content_dir: "posts"
  output_dir: "public"
  custom: "also preserved"
EOF
# Load only the Bash library functions; no writes outside the temporary directory.
source "$ROOT/lib/bash/common.sh"
source "$ROOT/lib/bash/sites.sh"
zeta_patch_yaml_section "$tmp/config.yaml" theme name aurora pandoc_theme espresso
zeta_patch_yaml_section "$tmp/config.yaml" site title 'Updated project'
grep -Fq 'blog: false' "$tmp/config.yaml"
grep -Fq 'image: "assets/cover.webp"' "$tmp/config.yaml"
grep -Fq 'custom: "preserved"' "$tmp/config.yaml"
grep -Fq 'custom: "also preserved"' "$tmp/config.yaml"
grep -Fq 'name: "aurora"' "$tmp/config.yaml"
grep -Fq 'pandoc_theme: "espresso"' "$tmp/config.yaml"
[[ "$(slugify 'Árbol Gestão Über Mañana Façade')" == arbol-gestao-uber-manana-facade ]]
[[ "$(slugify '😎 🤖')" == post ]]
ln -s "$ROOT/zeta.sh" "$tmp/zeta"
"$tmp/zeta" help > "$tmp/help.txt"
grep -Fq 'Interactive assistant' "$tmp/help.txt"
echo '[OK] YAML preservation, Unicode slugs, symlink invocation.'
