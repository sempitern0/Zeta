#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1090,SC1091

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
    printf 'Zeta requires Bash 4.3 or newer. Current version: %s\n' "$BASH_VERSION" >&2
    exit 2
fi

CURRENT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly CURRENT_DIR

SITES_DIR="${CURRENT_DIR}/sites"
TEMPLATES_DIR="${CURRENT_DIR}/templates"
PREVIEW_PORT="${ZETA_PORT:-8000}"

VERBOSE=false
FORCE=false
readonly SITES_DIR TEMPLATES_DIR

declare -gA TAG_MAP=()
declare -gA TAG_COUNT=()

source "${CURRENT_DIR}/lib/common.sh"

for module in "${CURRENT_DIR}/lib"/*.sh; do
    if [[ -f "$module" && "$module" != *"common.sh" ]]; then
        # shellcheck source=/dev/null
        source "$module"
    fi
done

main() {
    parse_args "$@"
    show_menu
}

trap 'exit 143' TERM
main "$@"
