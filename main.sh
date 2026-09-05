#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1090,SC1091

## Works on Linux/macOS
CURRENT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly CURRENT_DIR

## Load all the modules
source "${CURRENT_DIR}/lib/common.sh"

for module in "${CURRENT_DIR}/lib"/*.sh; do
    if [[ -f "$module" && "$module" != *"common.sh" ]]; then
        # shellcheck source=/dev/null
        source "$module"
    fi
done


main() {
    parse_args "$@"


    # -----------------------------------------------------------------------------
    # Application Entry Point
    # Place your main script logic or library module invocations below.
    # -----------------------------------------------------------------------------
}


trap 'cleanup 130' INT TERM
main "$@"