#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMPLATES_DIR="$ROOT/templates"
# shellcheck source=../lib/bash/common.sh
source "$ROOT/lib/bash/common.sh"
# shellcheck source=../lib/bash/sites.sh
source "$ROOT/lib/bash/sites.sh"
for theme in zen paper console indie organization brutalist folio aurora gazette magazine; do
  zeta_highlight_recommend "$theme"
  [[ -n "$ZETA_HIGHLIGHT_PRIMARY" && -n "$ZETA_HIGHLIGHT_REASON" ]]
  pandoc --list-highlight-styles | grep -Fqx "$ZETA_HIGHLIGHT_PRIMARY"
done
zeta_highlight_recommend paper
[[ "$ZETA_HIGHLIGHT_PRIMARY" == tango ]]
zeta_highlight_recommend console
[[ "$ZETA_HIGHLIGHT_PRIMARY" == breezedark ]]
echo '[OK] Theme-aware Pandoc highlighting recommendations'
