# shellcheck disable=SC2034,SC2329,SC2155,SC2154

if [[ -n "${NO_COLOR:-}" ]]; then
    boldWhite=""; boldCyan=""; boldYellow=""; boldGreen=""; boldRed=""; grayColour=""; endColour=""
fi

show_banner() {
    local g1="[38;5;51m"
    local g2="[38;5;45m"
    local g3="[38;5;39m"
    local g4="[38;5;63m"
    local g5="[38;5;99m"
    local g6="[38;5;135m"
    local sites_count=0

    if [[ -d "$SITES_DIR" ]]; then
        sites_count=$(get_all_sites | wc -l | tr -d ' ')
    fi

    printf '%b
' "${g1}  ███████╗███████╗████████╗ █████╗ ${endColour}"
    printf '%b
' "${g2}  ╚══███╔╝██╔════╝╚══██╔══╝██╔══██╗${endColour}"
    printf '%b
' "${g3}    ███╔╝ █████╗     ██║   ███████║${endColour}"
    printf '%b
' "${g4}   ███╔╝  ██╔══╝     ██║   ██╔══██║${endColour}"
    printf '%b
' "${g5}  ███████╗███████╗   ██║   ██║  ██║${endColour}"
    printf '%b
' "${g6}  ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝${endColour}"
    printf '%b
' "  ${boldWhite}ZETA${endColour} ${grayColour}— Markdown-first Static Site Generator${endColour}"
    printf '%b
' "  ${grayColour}Workspace:${endColour} ${boldCyan}${sites_count} site(s)${endColour} ${grayColour}| Engine: Bash + Pandoc | Output: public/${endColour}"
    print_separator
}

show_help() {
    show_banner
    cat <<EOF_HELP
Usage:
  ./main.sh [global options] <command> [arguments]
  ./main.sh                         Open the interactive assistant

Global options:
  -f, --force                      Skip destructive confirmations
  -v, --verbose                    Show additional diagnostic output
      --port PORT                  Preview port (default: ${PREVIEW_PORT})
  -h, --help                       Show this help

Site commands:
  create | new                     Create a local site workspace
  sites | list                     List sites and build status
  edit <site>                      Edit site metadata and theme
  theme <site> [theme] [style]     Change theme/highlighting and rebuild
  delete | rm <site>               Delete a site workspace
  clean <site>                     Remove only generated public/ output

Content commands:
  posts <site>                     List Markdown posts
  new-post <site>                  Create a Markdown post scaffold
  fonts <site>                     Manage optional open web fonts for a site
  doctor <site>                    Validate deploy readiness and show palettes

Build and preview:
  build | update <site>            Regenerate <site>/public/
  build-all                        Regenerate public/ for all sites
  preview <site> [port]            Build and serve one public/ directory
  serve [port]                     Build all sites and serve local dashboard
  dashboard | index                Regenerate sites/index.html only

Examples:
  ./main.sh create
  ./main.sh new-post my-blog
  ./main.sh posts my-blog
  ./main.sh theme my-blog paper zenburn
  ./main.sh build my-blog
  ./main.sh preview my-blog 8000
EOF_HELP
}

resolve_site_arg() {
    local requested="${1:-}"
    if [[ -n "$requested" ]]; then
        printf '%s\n' "$requested"
        return 0
    fi

    if [[ -t 0 && -t 1 ]]; then
        select_site_interactive
        return $?
    fi

    msg_error "A site slug is required in non-interactive mode."
    return 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --port)
                [[ $# -ge 2 ]] || { msg_error "--port requires a value."; exit 2; }
                PREVIEW_PORT="$2"
                shift 2
                ;;
            --port=*)
                PREVIEW_PORT="${1#*=}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                msg_error "Unknown option: $1"
                show_help
                exit 2
                ;;
            *)
                break
                ;;
        esac
    done

    if ! [[ "$PREVIEW_PORT" =~ ^[0-9]+$ ]] ||        ! (( PREVIEW_PORT >= 1 && PREVIEW_PORT <= 65535 )); then
        msg_error "Invalid preview port: '${PREVIEW_PORT}'."
        exit 2
    fi

    [[ $# -gt 0 ]] || return 0

    local command="$1"
    shift
    local site

    case "$command" in
        create|new)
            create_new_site
            ;;
        sites|list)
            list_sites
            ;;
        edit)
            site=$(resolve_site_arg "${1:-}") || exit 1
            edit_site "$site"
            ;;
        theme|appearance)
            site=$(resolve_site_arg "${1:-}") || exit 1
            change_site_appearance "$site" "${2:-}" "${3:-}"
            ;;
        delete|rm)
            site=$(resolve_site_arg "${1:-}") || exit 1
            delete_site "$site"
            ;;
        clean)
            site=$(resolve_site_arg "${1:-}") || exit 1
            clean_site "$site"
            ;;
        posts)
            site=$(resolve_site_arg "${1:-}") || exit 1
            list_posts "$site"
            ;;
        new-post)
            site=$(resolve_site_arg "${1:-}") || exit 1
            create_post "$site"
            ;;
        fonts)
            site=$(resolve_site_arg "${1:-}") || exit 1
            manage_site_fonts "$site"
            ;;
        doctor|diagnose|check-site)
            site=$(resolve_site_arg "${1:-}") || exit 1
            diagnose_site "$site"
            ;;
        build|update)
            if [[ $# -gt 0 ]]; then
                build_site "$1" && update_sites_index
            elif [[ -t 0 && -t 1 ]]; then
                site=$(select_site_interactive) || exit 1
                build_site "$site" && update_sites_index
            else
                build_all_sites
            fi
            ;;
        build-all)
            build_all_sites
            ;;
        preview)
            site=$(resolve_site_arg "${1:-}") || exit 1
            preview_site "$site" "${2:-$PREVIEW_PORT}"
            ;;
        serve)
            serve_workspace "${1:-$PREVIEW_PORT}"
            ;;
        dashboard|index)
            update_sites_index
            msg_success "Local dashboard updated: sites/index.html"
            ;;
        help)
            show_help
            ;;
        *)
            msg_error "Unknown command: '${command}'."
            show_help
            exit 2
            ;;
    esac

    local command_rc=$?
    exit "$command_rc"
}

pause_menu() {
    read -rp "Press Enter to continue..." _
}

select_and_build_site() {
    local site
    site=$(select_site_interactive) || return 0
    build_site "$site" && update_sites_index
}

select_and_preview_site() {
    local site
    site=$(select_site_interactive) || return 0
    preview_site "$site" "$PREVIEW_PORT"
}

manage_site_menu() {
    local site
    site=$(select_site_interactive) || return 0

    while true; do
        clear 2>/dev/null || true
        show_banner
        echo -e "${boldWhite}Manage: ${site}${endColour}"
        echo ""
        echo -e "  ${boldGreen}[1]${endColour} Edit site settings"
        echo -e "  ${boldGreen}[2]${endColour} Appearance: theme + code highlighting"
        echo -e "  ${boldGreen}[3]${endColour} List Markdown posts"
        echo -e "  ${boldGreen}[4]${endColour} Create a new post"
        echo -e "  ${boldGreen}[5]${endColour} Manage open web fonts"
        echo -e "  ${boldGreen}[6]${endColour} Diagnose deploy readiness + palettes"
        echo -e "  ${boldGreen}[7]${endColour} Build / update public/"
        echo -e "  ${boldGreen}[8]${endColour} Preview site locally"
        echo -e "  ${boldGreen}[9]${endColour} Clean generated public/"
        echo -e "  ${boldRed}[10]${endColour} Delete site"
        echo "  [0] Back"
        echo ""

        local option
        read -rp "$(printf '%b' "${boldCyan}Zeta ❯ ${endColour}")" option
        case "${option,,}" in
            1) edit_site "$site"; pause_menu ;;
            2) change_site_appearance "$site"; pause_menu ;;
            3) list_posts "$site"; pause_menu ;;
            4) create_post "$site"; pause_menu ;;
            5) manage_site_fonts "$site"; pause_menu ;;
            6) diagnose_site "$site"; pause_menu ;;
            7) build_site "$site" && update_sites_index; pause_menu ;;
            8) preview_site "$site" "$PREVIEW_PORT"; pause_menu ;;
            9) clean_site "$site"; pause_menu ;;
            10)
                delete_site "$site"
                [[ -d "${SITES_DIR}/${site}" ]] || return 0
                pause_menu
                ;;
            0|b|back) return 0 ;;
            *) msg_warn "Invalid option: '${option}'"; sleep 0.5 ;;
        esac
    done
}

show_menu() {
    while true; do
        clear 2>/dev/null || true
        show_banner

        if command_exists pandoc; then
            echo -e "${grayColour}Pandoc: available | Preview: Python 3 optional${endColour}"
        else
            echo -e "${boldYellow}Pandoc: missing (required only when building)${endColour}"
        fi
        echo ""
        echo -e "${boldWhite}Workspace${endColour}"
        echo -e "  ${boldGreen}[1]${endColour} List sites"
        echo -e "  ${boldGreen}[2]${endColour} Create site"
        echo -e "  ${boldGreen}[3]${endColour} Manage site"
        echo ""
        echo -e "${boldWhite}Build & preview${endColour}"
        echo -e "  ${boldGreen}[4]${endColour} Build one site"
        echo -e "  ${boldGreen}[5]${endColour} Build all sites"
        echo -e "  ${boldGreen}[6]${endColour} Preview one site"
        echo -e "  ${boldGreen}[7]${endColour} Serve complete local workspace"
        echo ""
        echo -e "  ${boldRed}[0]${endColour} Exit"
        print_separator

        local option
        read -rp "$(printf '%b' "${boldCyan}Zeta ❯ ${endColour}")" option
        case "${option,,}" in
            1) list_sites; pause_menu ;;
            2) create_new_site; pause_menu ;;
            3) manage_site_menu ;;
            4) select_and_build_site; pause_menu ;;
            5) build_all_sites; pause_menu ;;
            6) select_and_preview_site; pause_menu ;;
            7) serve_workspace "$PREVIEW_PORT"; pause_menu ;;
            0|q|quit|exit)
                msg_info "Goodbye."
                exit 0
                ;;
            *)
                msg_warn "Invalid option: '${option}'."
                sleep 0.5
                ;;
        esac
    done
}
