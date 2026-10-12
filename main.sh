#!/usr/bin/env bash
# Compatibility wrapper for existing users of main.sh.
set -euo pipefail
entry="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/zeta.sh"
exec bash "$entry" "$@"
