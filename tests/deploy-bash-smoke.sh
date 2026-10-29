#!/usr/bin/env bash
# Offline deployment regressions: do not contact GitHub or Cloudflare.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
SITES_DIR="$tmp/sites"
mkdir -p "$SITES_DIR/example/public"
cat > "$SITES_DIR/example/config.yaml" <<'YAML'
site:
  title: Example
  url: https://example.org
build:
  output_dir: public
YAML
printf '<!doctype html><title>Test</title>\n' > "$SITES_DIR/example/public/index.html"
cat > "$SITES_DIR/example/deploy.conf" <<'CONFIG'
provider=github-pages
repository=example/site
branch=gh-pages
project=
account=
CONFIG
# shellcheck source=../lib/bash/common.sh
source "$ROOT/lib/bash/common.sh"
# shellcheck source=../lib/bash/deploy.sh
source "$ROOT/lib/bash/deploy.sh"
require_site_slug() { [[ "$1" == example ]]; }
find_site_config() { printf '%s/config.yaml\n' "$1"; }
get_site_yaml_prop() { printf 'public\n'; }
is_safe_relative_dir() { [[ "$1" == public ]]; }
zeta_deploy_status example | grep -Fq 'example/site'
zeta_deploy_run example true > "$tmp/dry.log"
grep -Fq 'DRY RUN:' "$tmp/dry.log"
grep -Fq 'index.html' "$tmp/dry.log"
mkdir "$SITES_DIR/example/public/.git"
if zeta_deploy_run example true > /dev/null 2>&1; then echo 'Embedded .git was accepted' >&2; exit 1; fi
rmdir "$SITES_DIR/example/public/.git"
printf '# leaked\n' > "$SITES_DIR/example/public/secret.md"
if zeta_deploy_run example true > /dev/null 2>&1; then echo 'Markdown source was accepted' >&2; exit 1; fi
rm "$SITES_DIR/example/public/secret.md"
printf 'provider=github-pages\nrepository=../unsafe\nbranch=gh-pages\n' > "$SITES_DIR/example/deploy.conf"
if zeta_deploy_status example > /dev/null 2>&1; then echo 'Invalid repository was accepted' >&2; exit 1; fi
# Ensure the command dispatcher never launches setup implicitly.
# shellcheck source=../lib/bash/cli.sh
source "$ROOT/lib/bash/cli.sh"
zeta_deploy_run() { printf 'publish:%s:%s\n' "$1" "${2:-false}"; }
zeta_deploy_setup() { printf 'setup:%s\n' "$1"; }
zeta_deploy_status() { printf 'status:%s\n' "$1"; }
zeta_deployment_menu() { printf 'assistant:%s\n' "$1"; }
[[ "$(parse_args deploy example)" == 'publish:example:false' ]]
[[ "$(parse_args deploy setup example)" == 'setup:example' ]]
[[ "$(parse_args deploy status example)" == 'status:example' ]]
[[ "$(parse_args deploy --dry-run example)" == 'publish:example:true' ]]
[[ "$(parse_args deploy assistant example)" == 'assistant:example' ]]
echo '[OK] Deployment safety, offline dry-run and explicit command routing'
