#!/usr/bin/env bash
# Test independent providers, legacy migration and explicit target selection offline.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
SITES_DIR="$tmp/sites"
mkdir -p "$SITES_DIR/demo/public" "$SITES_DIR/demo/deploy"
cat > "$SITES_DIR/demo/config.yaml" <<'CONF'
site:
  url: https://example.org
build:
  output_dir: public
CONF
printf '<html><title>Demo</title></html>\n' > "$SITES_DIR/demo/public/index.html"
cat > "$SITES_DIR/demo/deploy.conf" <<'CONF'
provider=github-pages
repository=example/legacy
branch=gh-pages
project=
account=
CONF
cat > "$SITES_DIR/demo/deploy/cloudflare-pages.conf" <<'CONF'
provider=cloudflare-pages
repository=
branch=
project=demo-site
account=
CONF
# shellcheck source=../lib/bash/common.sh
source "$ROOT/lib/bash/common.sh"
# shellcheck source=../lib/bash/deploy.sh
source "$ROOT/lib/bash/deploy.sh"
require_site_slug() { [[ "$1" == demo ]]; }
find_site_config() { printf '%s/config.yaml\n' "$1"; }
get_site_yaml_prop() { printf 'public\n'; }
is_safe_relative_dir() { [[ "$1" == public ]]; }
zeta_deploy_status demo > "$tmp/status"
grep -Fq 'example/legacy' "$tmp/status"
grep -Fq 'demo-site' "$tmp/status"
zeta_deploy_choose demo all
[[ "${#ZETA_DEPLOY_SELECTED[@]}" == 2 ]]
zeta_deploy_choose demo cloudflare-pages
[[ "${ZETA_DEPLOY_SELECTED[*]}" == cloudflare-pages ]]
zeta_deploy_choose demo 1,2
[[ "${#ZETA_DEPLOY_SELECTED[@]}" == 2 ]]
if zeta_deploy_choose demo invalid >/dev/null 2>&1; then echo 'Invalid provider accepted' >&2; exit 1; fi
if zeta_deploy_choose demo >/dev/null 2>&1; then echo 'Noninteractive implicit multi-deploy accepted' >&2; exit 1; fi
zeta_deploy_run demo true all > "$tmp/dry"
grep -Fq 'github-pages cloudflare-pages' "$tmp/dry"
grep -Fq 'DRY RUN:' "$tmp/dry"
# New GitHub configuration overrides legacy without deleting it.
cat > "$SITES_DIR/demo/deploy/github-pages.conf" <<'CONF'
provider=github-pages
repository=example/new
branch=gh-pages
project=
account=
CONF
zeta_deploy_status demo > "$tmp/status2"
grep -Fq 'example/new' "$tmp/status2"
if grep -Fq 'example/legacy' "$tmp/status2"; then echo 'Legacy setting took precedence' >&2; exit 1; fi
echo '[OK] Multi-provider selection, legacy settings, precedence and safe offline dry-run'
