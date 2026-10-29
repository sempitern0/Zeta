# shellcheck disable=SC2034,SC2329,SC2155,SC2154

if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    boldWhite=""; boldCyan=""; boldYellow=""; boldGreen=""; boldRed=""; grayColour=""; endColour=""
fi


ui_rule() { printf '%*s\n' 70 '' | tr ' ' '-'; }
ui_heading() { printf '\n%b◆ %s%b\n' "$boldPurple" "$1" "$endColour"; }
ui_action() { if (( ${COLUMNS:-80} < 76 )); then printf '  %b[%s]%b %s\n' "$boldGreen" "$1" "$endColour" "$2"; else printf '  %b[%s]%b %-25s %b%s%b\n' "$boldGreen" "$1" "$endColour" "$2" "$grayColour" "$3" "$endColour"; fi; }

show_banner() {
    local -a sites=()
    readarray -t sites < <(get_all_sites)
    local colors=()
    if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]; then
        colors=($'\033[38;5;51m' $'\033[38;5;45m' $'\033[38;5;39m' $'\033[38;5;63m' $'\033[38;5;99m' $'\033[38;5;135m')
    else
        colors=('' '' '' '' '' '')
    fi
    local reset=''
    [[ -n "${colors[0]}" ]] && reset=$'\033[0m'
    if (( ${COLUMNS:-80} >= 69 )); then
        printf '%b\n' "${colors[0]}  ███████╗███████╗████████╗ █████╗ ${reset}"
        printf '%b\n' "${colors[1]}  ╚══███╔╝██╔════╝╚══██╔══╝██╔══██╗${reset}"
        printf '%b\n' "${colors[2]}    ███╔╝ █████╗     ██║   ███████║${reset}"
        printf '%b\n' "${colors[3]}   ███╔╝  ██╔══╝     ██║   ██╔══██║${reset}"
        printf '%b\n' "${colors[4]}  ███████╗███████╗   ██║   ██║  ██║${reset}"
        printf '%b\n' "${colors[5]}  ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝${reset}"
    fi
    printf '\n%bZETA%b  %b/ create · write · publish%b\n' "$boldCyan" "$endColour" "$grayColour" "$endColour"
    ui_rule
    printf '  Workspace   %b%s sites%b\n' "$boldWhite" "${#sites[@]}" "$endColour"
    printf '  Pipeline    Markdown > Pandoc > public/ > provider\n'
    if command_exists pandoc; then
        printf '  Renderer    %bready%b\n' "$boldGreen" "$endColour"
    else
        printf '  Renderer    %bPandoc unavailable%b\n' "$boldYellow" "$endColour"
    fi
    ui_rule
}


show_help() {
    show_banner
    cat <<EOF
Usage
  ./zeta.sh                          Interactive assistant
  ./zeta.sh [options] <command> [args]

Workspace
  sites | list                        List local sites and status
  create | new                        Create a site
  edit <site>                         Edit metadata and production URL
  theme <site> [theme] [style]        Theme and code highlighting
  clean <site>                        Remove generated output only
  delete <site>                       Delete site with confirmation

Content
  posts <site>                        List Markdown articles
  new-post <site>                     Create a Markdown article
  pages <site>                        List standalone Markdown pages
  new-page <site> [title] [slug]      Create and build a new page
  fonts <site> [recommended]          Manage or install theme-recommended fonts
  doctor <site>                       Check deploy readiness
  deploy setup <site>                 Guided provider configuration
  deploy assistant <site>             Interactive deployment control panel
  deploy <site>                       Build, validate and publish (never setup)
  deploy status <site>                Show destination configuration
  deploy --dry-run <site>             Inspect artifacts without publishing

Build / preview
  build | update <site>               Rebuild a site
  build-all                           Rebuild every site
  preview <site> [port]               Build + local browser preview
  serve [port]                        Build + workspace dashboard
  dashboard                           Update workspace index

Options
  -f, --force                         Skip supported confirmations
  -v, --verbose                       Verbose output
      --port N                        Preview port (default: ${PREVIEW_PORT})
  -h, --help                          Display this guide

Examples
  ./zeta.sh new-post my-site
  ./zeta.sh theme my-site indie zenburn
  ./zeta.sh doctor my-site
  ./zeta.sh preview my-site
  ./zeta.sh deploy setup my-site
  ./zeta.sh deploy my-site

Windows
  ./zeta.ps1 help
  ./zeta.ps1 build my-site
EOF
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
        pages)
            site=$(resolve_site_arg "${1:-}") || exit 1
            list_site_pages "$site"
            ;;
        new-page)
            site=$(resolve_site_arg "${1:-}") || exit 1
            create_site_page "$site" "${2:-}" "${3:-}"
            ;;
        fonts)
            site=$(resolve_site_arg "${1:-}") || exit 1
            manage_site_fonts "$site" "${2:-}"
            ;;
        doctor|diagnose|check-site)
            site=$(resolve_site_arg "${1:-}") || exit 1
            diagnose_site "$site"
            ;;
        deploy)
            case "${1:-}" in
                setup|configure)
                    shift
                    site=$(resolve_site_arg "${1:-}") || exit 1
                    zeta_deploy_setup "$site"
                    ;;
                assistant|menu)
                    shift
                    site=$(resolve_site_arg "${1:-}") || exit 1
                    zeta_deployment_menu "$site"
                    ;;
                status)
                    shift
                    site=$(resolve_site_arg "${1:-}") || exit 1
                    zeta_deploy_status "$site"
                    ;;
                --dry-run|dry-run)
                    shift
                    site=$(resolve_site_arg "${1:-}") || exit 1
                    zeta_deploy_run "$site" true "${2:-}"
                    ;;
                *)
                    site=$(resolve_site_arg "${1:-}") || exit 1
                    zeta_deploy_run "$site"
                    ;;
            esac
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


# Dedicated deployment assistant: configure is distinct from publish.
zeta_deployment_menu() {
    local site="${1:-}" choice
    if [[ -z "$site" ]]; then site=$(select_site_interactive) || return 1; fi
    require_site_slug "$site" || return 1
    find_site_config "${SITES_DIR}/${site}" >/dev/null || return 1
    while true; do
        if [[ -t 1 ]]; then clear 2>/dev/null || true; fi
        show_banner
        ui_heading "Deployment center / ${site}"
        printf '  %bCurrent destination%b\n' "$boldCyan" "$endColour"
        if [[ -f "$(zeta_deploy_file "$site")" ]]; then
            if ! zeta_deploy_status "$site"; then msg_warn 'Review the saved destination.'; fi
        else
            printf '  %bNot configured%b. Choose [1] to connect a provider.\n' "$boldYellow" "$endColour"
        fi
        ui_heading "Configure"
        ui_action 1 'Configure provider' 'GitHub Pages / Cloudflare Pages'
        ui_heading "Publish"
        ui_action 2 'Deploy now' 'build + Doctor + publish'
        ui_action 3 'Dry run' 'inspect output without remote writes'
        ui_action 4 'Destination details' 'read-only provider settings'
        printf '\n  %b[0]%b Back to site menu\n' "$grayColour" "$endColour"
        ui_rule
        read -rp "$(printf '%b' "${boldCyan}zeta / deploy / ${site} > ${endColour}")" choice
        case "${choice,,}" in
            1) if ! zeta_deploy_setup "$site"; then msg_warn 'Configuration was not changed.'; fi; pause_menu ;;
            2) if ! zeta_deploy_run "$site"; then msg_warn 'Deployment did not complete.'; fi; pause_menu ;;
            3) if ! zeta_deploy_run "$site" true; then msg_warn 'Dry run failed.'; fi; pause_menu ;;
            4) if ! zeta_deploy_status "$site"; then msg_warn 'Configure a provider first.'; fi; pause_menu ;;
            0|b|back) return 0 ;;
            *) msg_warn "Unknown option: $choice" ;;
        esac
    done
}

manage_site_menu() {
    local site
    site=$(select_site_interactive) || return 0
    while true; do
        if [[ -t 1 ]]; then clear 2>/dev/null || true; fi
        show_banner
        local config title theme output_rel status
        config=$(find_site_config "${SITES_DIR}/${site}") || return 1
        title=$(get_site_yaml_prop "$config" site title "$site")
        theme=$(get_site_yaml_prop "$config" theme name zen)
        output_rel=$(get_site_yaml_prop "$config" build output_dir public)
        status='draft'
        [[ -f "${SITES_DIR}/${site}/${output_rel}/index.html" ]] && status='built'
        ui_heading "Manage / ${title}"
        printf '  %b%s%b · %s posts · %s · %s\n' "$boldWhite" "$site" "$endColour" "$(site_post_count "$site")" "$theme" "$status"
        local publish_provider
        if zeta_deploy_read "$site" provider; then
            publish_provider="$ZETA_DEPLOY_VALUE"
            printf '  %bDeployment%b  %s configured\n' "$boldGreen" "$endColour" "$publish_provider"
        else
            printf '  %bDeployment%b  not configured\n' "$boldYellow" "$endColour"
        fi
        ui_heading "Content & appearance"
        ui_action 1 'Site settings' 'metadata / URL'
        ui_action 2 'Switch theme' 'appearance / highlighting'
        ui_action 3 'List posts' 'Markdown library'
        ui_action 4 'New post' 'guided scaffold'
        ui_action 5 'Manage fonts' 'optional fonts'
        ui_action 11 'List pages' 'standalone Markdown pages'
        ui_action 12 'New page' 'create an About, project or other page'
        ui_heading "Build & validate"
        ui_action 6 'Doctor' 'pre-publish checks'
        ui_action 7 'Build' 'regenerate public/'
        ui_action 8 'Preview' 'localhost server'
        ui_heading "Publish"
        ui_action 13 'Deployment center' 'configure / publish / inspect'
        ui_action 14 'Deploy now' 'build + Doctor + publish'
        ui_heading "Maintenance"
        ui_action 9 'Clean' 'remove generated files'
        ui_action 10 'Delete site' 'confirmation required'
        printf '\n  [0] Back\n'
        ui_rule
        local option
        read -rp "$(printf '%b' "${boldCyan}zeta / ${site} > ${endColour}")" option
        case "${option,,}" in
            1) edit_site "$site"; pause_menu ;;
            2) change_site_appearance "$site"; pause_menu ;;
            3) list_posts "$site"; pause_menu ;;
            4) create_post "$site"; pause_menu ;;
            5) manage_site_fonts "$site"; pause_menu ;;
            11) list_site_pages "$site"; pause_menu ;;
            12) create_site_page "$site"; pause_menu ;;
            6) diagnose_site "$site"; pause_menu ;;
            7) build_site "$site" && update_sites_index; pause_menu ;;
            8) preview_site "$site" "$PREVIEW_PORT"; pause_menu ;;
            13) zeta_deployment_menu "$site" ;;
            14) if ! zeta_deploy_run "$site"; then msg_warn 'Deployment did not complete.'; fi; pause_menu ;;
            9) clean_site "$site"; pause_menu ;;
            10) delete_site "$site"; [[ -d "${SITES_DIR}/${site}" ]] || return 0; pause_menu ;;
            0|b|back) return 0 ;;
            *) msg_warn "Unknown option: '$option'"; sleep 0.4 ;;
        esac
    done
}


show_menu() {
    while true; do
        if [[ -t 1 ]]; then clear 2>/dev/null || true; fi
        show_banner
        local -a projects=()
        readarray -t projects < <(get_all_sites)
        ui_heading "Your sites"
        if (( ${#projects[@]} > 0 )); then printf '  %b%-22s %-12s %-11s %-6s %s%b\n' "$grayColour" 'SITE' 'CONTENT' 'THEME' 'BUILD' 'DEPLOY' "$endColour"; fi
        if (( ${#projects[@]} == 0 )); then
            printf '  %bNo sites yet. Choose [2] to create one.%b\n' "$grayColour" "$endColour"
        else
            local site config theme output_rel status shown=0
            for site in "${projects[@]}"; do
                (( shown >= 4 )) && break
                config=$(find_site_config "${SITES_DIR}/${site}") || continue
                theme=$(get_site_yaml_prop "$config" theme name zen)
                output_rel=$(get_site_yaml_prop "$config" build output_dir public)
                status='draft'
                [[ -f "${SITES_DIR}/${site}/${output_rel}/index.html" ]] && status='built'
                local publishing='not set'
                if zeta_deploy_read "$site" provider; then publishing="$ZETA_DEPLOY_VALUE"; fi
                printf '  %-22.22s %3s posts   %-11.11s %-6s %s\n' "$site" "$(site_post_count "$site")" "$theme" "$status" "$publishing"
                ((shown+=1))
            done
            if (( ${#projects[@]} > 4 )); then
                printf '  + %s more (see [1])\n' "$((${#projects[@]} - 4))"
            fi
        fi
        ui_heading "Workspace"
        ui_action 1 'List sites' 'status / content'
        ui_action 2 'Create site' 'new workspace'
        ui_action 3 'Manage site' 'content / appearance'
        ui_heading "Build & preview"
        ui_action 8 'Deployment center' 'configure / publish / inspect'
        ui_action 4 'Build one' 'generate public/'
        ui_action 5 'Build all' 'all workspaces'
        ui_action 6 'Preview one' 'local browser'
        ui_action 7 'Serve workspace' 'local dashboard'
        printf '\n  [?] Help     [0] Exit\n'
        ui_rule
        local option
        read -rp "$(printf '%b' "${boldCyan}zeta > ${endColour}")" option
        case "${option,,}" in
            1) list_sites; pause_menu ;;
            2) create_new_site; pause_menu ;;
            3) manage_site_menu ;;
            4) select_and_build_site; pause_menu ;;
            5) build_all_sites; pause_menu ;;
            6) select_and_preview_site; pause_menu ;;
            7) serve_workspace "$PREVIEW_PORT"; pause_menu ;;
            8) site=$(select_site_interactive) || continue; zeta_deployment_menu "$site" ;;
            '?'|h|help) show_help; pause_menu ;;
            0|q|quit|exit) msg_info "Goodbye."; exit 0 ;;
            *) msg_warn "Unknown option: '$option'"; sleep 0.4 ;;
        esac
    done
}
