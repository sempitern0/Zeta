#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1090,SC1091

## Works on Linux/macOS
CURRENT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
TARGET_USER="${SUDO_USER:-${USER:-$(whoami)}}"

if command -v getent >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
else
    TARGET_HOME="$(eval echo "~${TARGET_USER}")"
fi

readonly CURRENT_DIR
readonly TARGET_USER
readonly TARGET_HOME

SITES_DIR="${CURRENT_DIR}/sites"
TEMPLATES_DIR="${CURRENT_DIR}/templates"

VERBOSE=false
FORCE=false
MINIFY=false
HAS_HTML_CSS_MINIFIER=false
HAS_IMAGE_OPTIMIZER=false

declare -gA TAG_MAP=()
declare -gA TAG_COUNT=()

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
    show_menu
}


trap 'cleanup 130' INT TERM
main "$@"



# [ Ejecución del Script ]
#                                   │
#                                   ▼
#                    ┌─────────────────────────────┐
#                    │ 1. Actualización Automática │
#                    │    Index del Dashboard      │
#                    └──────────────┬──────────────┘
#                                   │
#                                   ▼
#                    ┌─────────────────────────────┐
#                    │   2. Menú Principal CLI     │
#                    └──────────────┬──────────────┘
#                                   │
#          ┌────────────────────────┴────────────────────────┐
#          ▼                                                 ▼
# [ Opción: Crear Nuevo Sitio ]            [ Opción: Compilar Sitio Existente ]
#          │                                                 │
#          ▼                                                 ▼
# ┌─────────────────────────┐               ┌─────────────────────────┐
# │ 3A. Asistente Inicial   │               │ 3B. Escanear carpeta    │
# │ (Inputs de configuración)│               │ sites/<blog>/posts/*.md │
# └────────┬────────────────┘               └────────┬────────────────┘
#          │                                                 │
#          ▼                                                 ▼
# ┌─────────────────────────┐               ┌─────────────────────────┐
# │ 4A. Crear estructura    │               │ 4B. Extraer Frontmatter │
# │ sites/<nuevoblog>/posts/│               │ + Convertir MD (Pandoc) │
# └────────┬────────────────┘               └────────┬────────────────┘
#          │                                                 │
#          ▼                                                 ▼
# ┌─────────────────────────┐               ┌─────────────────────────┐
# │ 5A. Generar Markdown    │               │ 5B. Inyectar variables  │
# │ de prueba con metadatos │               │ en article.html y index │
# └────────┬────────────────┘               └────────┬────────────────┘
#          │                                                 │
#          │                                                 ▼
#          │                                ┌─────────────────────────┐
#          │                                │ 6B. Volcar HTMLs en     │
#          │                                │ la raíz de sites/<blog>/│
#          │                                └────────┬────────────────┘
#          │                                                 │
#          └────────────────────────┬────────────────────────┘
#                                   │
#                                   ▼
#                    ┌─────────────────────────────┐
#                    │  Fin / Servido vía Docker   │
#                    └─────────────────────────────┘