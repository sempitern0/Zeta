#!/usr/bin/env bash
# Zeta deploy: plain data configuration (never source the config as shell code).
# shellcheck disable=SC2310
zeta_deploy_file() { printf '%s/deploy.conf\n' "${SITES_DIR}/$1"; }
zeta_deploy_read() {
    local key="$2" line
    ZETA_DEPLOY_VALUE=''
    [[ -f "$(zeta_deploy_file "$1")" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in "$key="*) ZETA_DEPLOY_VALUE="${line#*=}"; return 0 ;; esac
    done < "$(zeta_deploy_file "$1")"
    return 1
}
zeta_deploy_valid_repo() { [[ "$1" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]] && [[ "$1" != *..* ]]; }
zeta_deploy_valid_slug() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; }
zeta_deploy_setup() {
    local site="$1" provider choice repo branch project account
    require_site_slug "$site" || return 1
    [[ -f "${SITES_DIR}/$site/config.yaml" || -f "${SITES_DIR}/$site/config.yml" ]] || { msg_error "Unknown site: $site"; return 1; }
    [[ -t 0 ]] || { msg_error "Setup needs an interactive terminal."; return 1; }
    printf '\nZETA / Deploy setup for %s\n  [1] GitHub Pages\n  [2] Cloudflare Pages\n' "$site"
    read -rp 'Choose provider [1]: ' choice
    case "${choice:-1}" in 1) provider=github-pages ;; 2) provider=cloudflare-pages ;; *) msg_error 'Invalid provider'; return 1 ;; esac
    repo='';branch='';project='';account=''
    if [[ "$provider" == github-pages ]]; then
        read -rp 'GitHub repository (owner/repository): ' repo
        zeta_deploy_valid_repo "$repo" || { msg_error 'Repository must be owner/repository'; return 1; }
        read -rp 'Publishing branch [gh-pages]: ' branch
        branch="${branch:-gh-pages}"
        [[ "$branch" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ && "$branch" != *..* && "$branch" != */ && "$branch" != *//* ]] || { msg_error 'Unsafe branch'; return 1; }
    else
        read -rp 'Cloudflare Pages project name: ' project
        zeta_deploy_valid_slug "$project" || { msg_error 'Invalid project name'; return 1; }
        read -rp 'Cloudflare account ID (optional): ' account
        [[ -z "$account" || "$account" =~ ^[a-fA-F0-9]{32}$ ]] || { msg_error 'Invalid account ID'; return 1; }
    fi
    printf '\nProvider: %s\nSite: %s\n' "$provider" "$site"
    [[ -n "$repo" ]] && printf 'Repository: %s (%s)\n' "$repo" "$branch"
    [[ -n "$project" ]] && printf 'Project: %s\n' "$project"
    read -rp 'Save deployment configuration? [y/N]: ' choice
    [[ "$choice" =~ ^[YySs] ]] || { msg_info 'Cancelled'; return 0; }
    local cfg;cfg=$(zeta_deploy_file "$site")
    local tmp="${cfg}.tmp.$$"
    ( umask 077; printf 'provider=%s\nrepository=%s\nbranch=%s\nproject=%s\naccount=%s\n' "$provider" "$repo" "$branch" "$project" "$account" > "$tmp" )
    mv -f -- "$tmp" "$cfg"
    msg_success "Saved deploy configuration for $site. Use: ./zeta.sh deploy $site"
}
zeta_deploy_status() {
    local site="$1" provider repo branch project
    require_site_slug "$site" || return 1
    zeta_deploy_read "$site" provider || { msg_warn "Not configured. Run: ./zeta.sh deploy setup $site"; return 1; }
    provider="$ZETA_DEPLOY_VALUE"
    printf 'Site: %s\nProvider: %s\n' "$site" "$provider"
    case "$provider" in
        github-pages)
            zeta_deploy_read "$site" repository || return 1; repo="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read "$site" branch || return 1; branch="$ZETA_DEPLOY_VALUE"
            zeta_deploy_valid_repo "$repo" || return 1
            printf 'Destination: %s, branch %s\n' "$repo" "$branch" ;;
        cloudflare-pages)
            zeta_deploy_read "$site" project || return 1; project="$ZETA_DEPLOY_VALUE"
            zeta_deploy_valid_slug "$project" || return 1
            printf 'Project: %s\n' "$project" ;;
        *) msg_error 'Unknown provider in deploy.conf'; return 1 ;;
    esac
}
zeta_deploy_run() {
    local site="$1" dry="${2:-false}" cfg output_rel output provider repo branch project account reply tmp remote
    require_site_slug "$site" || return 1
    cfg=$(find_site_config "${SITES_DIR}/$site") || return 1
    zeta_deploy_read "$site" provider || { msg_error "Run deploy setup $site first"; return 1; }
    provider="$ZETA_DEPLOY_VALUE"
    output_rel=$(get_site_yaml_prop "$cfg" build output_dir public)
    is_safe_relative_dir "$output_rel" || { msg_error 'Unsafe build output'; return 1; }
    output="${SITES_DIR}/$site/$output_rel"
    if [[ "$dry" != true ]]; then
        build_site "$site" || return 1
        diagnose_site "$site" || return 1
    fi
    [[ -s "$output/index.html" ]] || { msg_error "No index.html in $output"; return 1; }
    [[ ! -L "$output" ]] || { msg_error 'Output cannot be a symlink'; return 1; }
    if find "$output" -type l -print -quit | grep -q .; then msg_error 'Output contains symlinks'; return 1; fi
    local bad
    bad=$(find "$output" -type f \( -name '*.md' -o -name 'config.yaml' -o -name 'deploy.conf' -o -name '.env' \) -print -quit)
    [[ -z "$bad" ]] || { msg_error "Refusing to publish source/config file: $bad"; return 1; }
    zeta_deploy_status "$site" || return 1
    if [[ "$dry" == true ]]; then printf 'DRY RUN: no uploads or remote changes. Files:\n'; find "$output" -type f | sed "s|^$output/||" | sort; return 0; fi
    if [[ -t 0 ]]; then
        read -rp 'Publish this site now? [y/N]: ' reply
        [[ "$reply" =~ ^[YySs] ]] || { msg_info 'Cancelled'; return 0; }
    fi
    if [[ "$provider" == github-pages ]]; then
        command_exists git || { msg_error 'Install Git first'; return 1; }
        zeta_deploy_read "$site" repository; repo="$ZETA_DEPLOY_VALUE"
        zeta_deploy_read "$site" branch; branch="$ZETA_DEPLOY_VALUE"
        zeta_deploy_valid_repo "$repo" || return 1
        [[ "$branch" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ && "$branch" != *..* ]] || return 1
        remote="https://github.com/$repo.git"
        tmp=$(mktemp -d) || return 1
        if ! git clone -q --depth 1 --branch "$branch" "$remote" "$tmp"; then rm -rf -- "$tmp"; msg_error "Could not clone $branch. Create it and enable Pages from branch/root first."; return 1; fi
        # Preserve the existing .git repository, but replace only tracked site content.
        (cd "$tmp" && git ls-files -z | xargs -0 -r rm -f --) || { rm -rf -- "$tmp"; return 1; }
        # Copy generated dotfiles as well; do not copy hidden directories from source repos.
        cp -a "$output/." "$tmp/" || { rm -rf -- "$tmp"; return 1; }
        : > "$tmp/.nojekyll"
        (cd "$tmp" && git add -A && if ! git diff --cached --quiet; then git -c user.name='Zeta Deploy' -c user.email='zeta-deploy@users.noreply.github.com' commit -qm "Deploy $site" && git push origin "$branch"; else echo 'No changes to deploy'; fi)
        local rc=$?; rm -rf -- "$tmp"; return "$rc"
    elif [[ "$provider" == cloudflare-pages ]]; then
        command_exists wrangler || { msg_error 'Install Wrangler CLI and login with wrangler login'; return 1; }
        zeta_deploy_read "$site" project; project="$ZETA_DEPLOY_VALUE"
        zeta_deploy_valid_slug "$project" || return 1
        zeta_deploy_read "$site" account || true; account="$ZETA_DEPLOY_VALUE"
        if [[ -n "$account" ]]; then CLOUDFLARE_ACCOUNT_ID="$account" wrangler pages deploy "$output" --project-name "$project"; else wrangler pages deploy "$output" --project-name "$project"; fi
    else msg_error 'Unsupported provider'; return 1
    fi
}
