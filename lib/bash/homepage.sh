#!/usr/bin/env bash
# Guided homepage preferences, independent of the selected theme.
zeta_homepage_setup() {
    local site="$1" mode="${2:-}" limit="${3:-}" config current_mode current_limit temp
    require_site_slug "$site" || return 1
    config=$(find_site_config "$SITES_DIR/$site") || return 1
    current_mode=$(get_site_yaml_prop "$config" homepage show_posts auto)
    current_limit=$(get_site_yaml_prop "$config" homepage posts_limit 6)
    if [[ -z "$mode" ]]; then
        [[ -t 0 ]] || { msg_error 'Usage: homepage SITE [auto|true|false] [1..30]'; return 1; }
        printf '\nZETA / Homepage / %s\n' "$site"
        printf '  auto: show stories on newspaper/magazine themes\n'
        read -rp "Show articles [auto/true/false] [$current_mode]: " mode
        mode="${mode:-$current_mode}"
        read -rp "Number of recent articles [$current_limit]: " limit
    fi
    limit="${limit:-$current_limit}"
    [[ "$mode" == auto || "$mode" == true || "$mode" == false ]] || { msg_error 'Use auto, true or false'; return 1; }
    [[ "$limit" =~ ^[0-9]+$ ]] && (( limit >= 1 && limit <= 30 )) || { msg_error 'Article limit must be 1..30'; return 1; }
    temp="$config.homepage-tmp.$$"
    awk -v show="$mode" -v limit="$limit" '
      /^homepage:[[:space:]]*$/ {inside=1;found=1;print;print "  show_posts: " show;print "  posts_limit: " limit;next}
      inside && /^[^[:space:]#]/ {inside=0}
      inside && /^[[:space:]]+(show_posts|posts_limit):/ {next}
      {print}
      END {if(!found){print "homepage:";print "  show_posts: " show;print "  posts_limit: " limit}}
    ' "$config" > "$temp" || { rm -f -- "$temp"; return 1; }
    mv -f -- "$temp" "$config"
    msg_success "Homepage: show_posts=$mode, posts_limit=$limit. Rebuild to apply."
}
