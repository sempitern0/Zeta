
# shellcheck disable=SC2034,SC2329

VERBOSE=false
FORCE=false

# shellcheck disable=SC2317
cleanup() {
    echo ""
    msg_error "Script execution interrupted by user (Ctrl + C). Cleaning up..."
    exit 130
}

parse_args() {
    local OPTIND opt

    # GETOPTS STRING RULES:
    #   'v'  -> Short flag without value (boolean flag)
    #   'o:' -> Short option with trailing colon requires a value (-o <file>)
    #   '-'  -> Catches long options starting with '--'
    while getopts "o:c:fvh-:" opt; do
        case "$opt" in
            # ------------------------------------------------------------------
            # 1. SHORT OPTIONS WITH VALUES (-o <value>, -c <value>)
            # ------------------------------------------------------------------
            o) OUTPUT_FILE="$OPTARG" ;;
            c) CONFIG_FILE="$OPTARG" ;;

            # ------------------------------------------------------------------
            # 2. SHORT BOOLEAN FLAGS (-f, -v, -h)
            # ------------------------------------------------------------------
            f) FORCE=true ;;
            v) VERBOSE=true ;;
            h)
                show_help
                exit 0
                ;;

            # ------------------------------------------------------------------
            # 3. LONG OPTIONS (--output, --config, --force, --verbose)
            # ------------------------------------------------------------------
            -)
                case "${OPTARG}" in
                    # Long boolean flags
                    force)   FORCE=true ;;
                    verbose) VERBOSE=true ;;
                    help)
                        show_help
                        exit 0
                        ;;

                    # Long options with '=' syntax (--output=file.txt)
                    output=*) OUTPUT_FILE="${OPTARG#*=}" ;;
                    config=*) CONFIG_FILE="${OPTARG#*=}" ;;

                    # Long options with space syntax (--output file.txt)
                    output)
                        OUTPUT_FILE="${!OPTIND}"
                        OPTIND=$((OPTIND + 1))
                        ;;
                    config)
                        CONFIG_FILE="${!OPTIND}"
                        OPTIND=$((OPTIND + 1))
                        ;;

                    *)
                        msg_error "Unknown option: --${OPTARG}"
                        show_help
                        exit 1
                        ;;
                esac
                ;;

            # ------------------------------------------------------------------
            # 4. INVALID SHORT OPTIONS
            # ------------------------------------------------------------------
            \?)
                msg_error "Invalid option: -$OPTARG"
                show_help
                exit 1
                ;;
        esac
    done

    shift $((OPTIND - 1))
}

cleanup() {
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    echo ""
    
    msg_error "Execution interrupted or failed with exit code $exit_code. Cleaning up..."
    exit "$exit_code"
}