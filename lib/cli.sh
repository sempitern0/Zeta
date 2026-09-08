# shellcheck disable=SC2034,SC2329,SC2155,SC2154

boldWhite="${boldWhite:-\033[1;37m}"
boldCyan="${boldCyan:-\033[1;36m}"
boldYellow="${boldYellow:-\033[1;33m}"
boldGreen="${boldGreen:-\033[1;32m}"
boldRed="${boldRed:-\033[1;31m}"
grayColour="${grayColour:-\033[0;90m}"
endColour="${endColour:-\033[0m}"

show_banner() {
    local g1="\033[38;5;51m"
    local g2="\033[38;5;45m"
    local g3="\033[38;5;39m"
    local g4="\033[38;5;63m"
    local g5="\033[38;5;99m"
    local g6="\033[38;5;135m"

    echo -e "${g1}  ███████╗███████╗████████╗█████╗ ${endColour}"
    echo -e "${g2}  ╚══███╔╝██╔════╝╚══██╔══╝██╔══██╗${endColour}"
    echo -e "${g3}    ███╔╝ █████╗     ██║   ███████║${endColour}"
    echo -e "${g4}   ███╔╝  ██╔══╝     ██║   ██╔══██║${endColour}"
    echo -e "${g5}  ███████╗███████╗   ██║   ██║  ██║${endColour}"
    echo -e "${g6}  ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝${endColour}"
    
    echo -e "  ${boldWhite}ZETA${endColour} ${grayColour}— Static Site Generator for Hackers & Devs${endColour} ${g6}(v1.0)${endColour}"

    local sites_count=0
    local target_dir="${SITES_DIR:-sites}"

    if [[ -d "$target_dir" ]]; then
        for d in "$target_dir"/*/; do
            [[ -d "$d" ]] && ((++sites_count))
        done
    fi

    echo -e "  ${grayColour}⚡ Local workspace:${endColour} ${boldCyan}${sites_count} site(s)${endColour} ${grayColour}| Engine: Bash + Pandoc${endColour}"
    print_separator
}

show_help() {
    show_banner
    echo -e "${boldWhite}Usage:${endColour} $0 [options] [command]\n"
    
    echo -e "${boldWhite}Options:${endColour}"
    printf "  %-22s %s\n" "-f, --force" "Force overwrite operations without asking"
    printf "  %-22s %s\n" "-v, --verbose" "Enable detailed execution logging"
    printf "  %-22s %s\n\n" "-h, --help" "Show this CLI help interface"

    echo -e "${boldWhite}Commands:${endColour}"
    printf "  %-22s %s\n" "new, create" "Launch interactive site creation wizard"
    printf "  %-22s %s\n" "build [slug]" "Build target site (or all if slug is omitted)"
    printf "  %-22s %s\n" "build-all" "Batch build all existing sites in workspace"
    printf "  %-22s %s\n" "index" "Recompile root dashboard (sites/index.html)"
    printf "  %-22s %s\n\n" "help" "Display usage information"
}

parse_args() {
    local OPTIND opt

    while getopts "fvh-:" opt; do
        case "$opt" in
            f) FORCE=true ;;
            v) VERBOSE=true ;;
            h)
                show_help
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    force)   FORCE=true ;;
                    verbose) VERBOSE=true ;;
                    help)
                        show_help
                        exit 0
                        ;;
                    output=*) OUTPUT_FILE="${OPTARG#*=}" ;;
                    config=*) CONFIG_FILE="${OPTARG#*=}" ;;
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
            \?)
                msg_error "Invalid option: -$OPTARG"
                show_help
                exit 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    if [[ $# -gt 0 ]]; then
        local command="$1"
        shift

        case "$command" in
            new|create)
                create_new_site
                exit 0
                ;;
            build)
                if [[ $# -gt 0 && -n "$1" ]]; then
                    build_site "$1"
                else
                    build_all_sites
                fi
                exit 0
                ;;
            build-all)
                build_all_sites
                exit 0
                ;;
            index)
                update_sites_index
                exit 0
                ;;
            help)
                show_help
                exit 0
                ;;
            *)
                msg_error "Unknown command: '$command'"
                show_help
                exit 1
                ;;
        esac
    fi
}


select_and_build_site() {
    local available_sites=()
    readarray -t available_sites < <(get_all_sites)

    if [[ ${#available_sites[@]} -eq 0 ]]; then
        msg_warn "No sites available to build."
        return 0
    fi

    echo -e "\nSelect site to build:\n"
    local idx=1
    for site in "${available_sites[@]}"; do
        echo -e "  [${idx}] ${site}"
        ((idx++))
    done

    echo ""
    read -rp "Zeta ▶ Select option [1 - ${#available_sites[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#available_sites[@]} )); then
        local selected_slug="${available_sites[$((choice - 1))]}"
        
        build_site "$selected_slug"
        update_sites_index
    else
        msg_error "Invalid selection."
    fi
}

show_menu() {
    while true; do
        clear 2>/dev/null || true
        show_banner
        
        echo -e "${boldYellow}Workspace Commands:${endColour}\n"
        echo -e "  ${boldGreen}[1]${endColour} ✨ ${boldWhite}Create new site${endColour}            ${grayColour}(Interactive wizard)${endColour}"
        echo -e "  ${boldGreen}[2]${endColour} 📦 ${boldWhite}Build specific site${endColour}        ${grayColour}(Select from list)${endColour}"
        echo -e "  ${boldGreen}[3]${endColour} 🚀 ${boldWhite}Build ALL sites${endColour}            ${grayColour}(Batch build)${endColour}"
        echo -e "  ${boldGreen}[4]${endColour} 📊 ${boldWhite}Rebuild main Dashboard${endColour}     ${grayColour}(sites/index.html)${endColour}"
        echo -e "  ${boldGreen}[0]${endColour} 🚪 ${boldWhite}Exit generator${endColour}             ${grayColour}(q, quit, exit)${endColour}\n"
        print_separator

        read -rp "$(echo -e "${boldCyan}Zeta ❯ ${endColour}")" option
        
        case "${option,,}" in
            1)
                echo ""
                create_new_site
                read -rp "$(echo -e "\n${grayColour}Press Enter to return to main menu...${endColour}")"
                ;;
            2)
                echo ""
                select_and_build_site
                read -rp "$(echo -e "\n${grayColour}Press Enter to return to main menu...${endColour}")"
                ;;
            3)
                echo ""
                build_all_sites
                read -rp "$(echo -e "\n${grayColour}Press Enter to return to main menu...${endColour}")"
                ;;
            4)
                echo ""
                update_sites_index
                read -rp "$(echo -e "\n${grayColour}Press Enter to return to main menu...${endColour}")"
                ;;
            0|q|quit|exit|bye)
                echo ""
                msg_info "Exiting Zeta. Happy Hacking!"
                exit 0
                ;;
            *)
                msg_warn "Invalid option: '$option'"
                sleep 0.8
                ;;
        esac
    done
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        msg_error "Execution failed or was interrupted (exit code $exit_code)."
    fi
    exit "$exit_code"
}
