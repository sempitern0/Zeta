# shellcheck disable=SC2034,SC2329

redColour=$'\033[0;31m'
greenColour=$'\033[0;32m'
yellowColour=$'\033[0;33m'
blueColour=$'\033[0;34m'
purpleColour=$'\033[0;35m'
cyanColour=$'\033[0;36m'
grayColour=$'\033[0;90m'

boldRed=$'\033[1;31m'
boldGreen=$'\033[1;32m'
boldYellow=$'\033[1;33m'
boldBlue=$'\033[1;34m'
boldPurple=$'\033[1;35m'
boldCyan=$'\033[1;36m'
boldWhite=$'\033[1;37m'
endColour=$'\033[0m'

msg_info()    { echo -e "${cyanColour}[INFO]${endColour} $*" >&2; }
msg_success() { echo -e "${greenColour}[OK]${endColour} $*" >&2; }
msg_warn()    { echo -e "${yellowColour}[WARN]${endColour} $*" >&2; }
msg_error()   { echo -e "${redColour}[ERROR]${endColour} $*" >&2; }
msg_build()   { echo -e "${boldCyan}[BUILD]${endColour} $*" >&2; }
msg_debug()   { [[ "${VERBOSE:-false}" == true ]] && echo -e "${grayColour}[DEBUG]${endColour} $*" >&2 || true; }

print_separator() {
    echo -e "${grayColour}------------------------------------------------------------${endColour}"
}

print_section() {
    echo -e "\n${boldWhite}===> $*${endColour}" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

die() {
    msg_error "$*"
    exit 1
}

slugify() {
    local value="${1:-}"
    value="${value,,}"
    value="${value//á/a}"
    value="${value//é/e}"
    value="${value//í/i}"
    value="${value//ó/o}"
    value="${value//ú/u}"
    value="${value//ñ/n}"
    value=$(printf '%s' "$value" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
    printf '%s\n' "$value"
}
