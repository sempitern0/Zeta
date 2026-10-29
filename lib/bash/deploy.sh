#!/usr/bin/env bash
# Zeta deployment providers. Config files are DATA, never sourced as shell code.
# Each provider has one saved target. Legacy deploy.conf is read without migration.
# shellcheck disable=SC2310
zeta_deploy_file() { printf '%s/deploy.conf\n' "$SITES_DIR/$1"; }
zeta_deploy_target_file() { printf '%s/deploy/%s.conf\n' "$SITES_DIR/$1" "$2"; }
zeta_deploy_valid_repo() { [[ "$1" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ && "$1" != *..* ]]; }
zeta_deploy_valid_slug() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; }
zeta_deploy_valid_branch() {
    [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ && "$1" != *..* && "$1" != */ && "$1" != *//* ]]
}
zeta_deploy_read_file() {
    local file="$1" key="$2" line
    ZETA_DEPLOY_VALUE=''
    [[ -f "$file" && ! -L "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        case "$line" in
            "$key="*) ZETA_DEPLOY_VALUE="${line#*=}"; return 0 ;;
        esac
    done < "$file"
    return 1
}
zeta_deploy_resolve_file() {
    local site="$1" provider="$2" new legacy
    case "$provider" in github-pages|cloudflare-pages) ;; *) return 1 ;; esac
    new=$(zeta_deploy_target_file "$site" "$provider")
    if [[ -e "$new" ]]; then
        [[ -f "$new" && ! -L "$new" ]] || return 1
        printf '%s\n' "$new"
        return 0
    fi
    legacy=$(zeta_deploy_file "$site")
    if zeta_deploy_read_file "$legacy" provider && [[ "$ZETA_DEPLOY_VALUE" == "$provider" ]]; then
        printf '%s\n' "$legacy"
        return 0
    fi
    return 1
}
zeta_deploy_targets() {
    local site="$1" provider
    for provider in github-pages cloudflare-pages; do
        if zeta_deploy_resolve_file "$site" "$provider" >/dev/null; then
            printf '%s\n' "$provider"
        fi
    done
}
# Compatibility for site dashboard and legacy smoke fixtures.
zeta_deploy_read() {
    local site="$1" key="$2" provider file
    while IFS= read -r provider; do
        file=$(zeta_deploy_resolve_file "$site" "$provider") || continue
        zeta_deploy_read_file "$file" "$key" && return 0
    done < <(zeta_deploy_targets "$site")
    return 1
}
zeta_deploy_summary() {
    local site="$1" providers=()
    mapfile -t providers < <(zeta_deploy_targets "$site")
    case "${#providers[@]}" in
        0) printf 'not configured\n' ;;
        1) printf '%s\n' "${providers[0]}" ;;
        *) printf '%s providers\n' "${#providers[@]}" ;;
    esac
}
zeta_deploy_validate() {
    local site="$1" provider="$2" file stored repo branch project account
    file=$(zeta_deploy_resolve_file "$site" "$provider") || { msg_error "No $provider target configured"; return 1; }
    zeta_deploy_read_file "$file" provider || return 1; stored="$ZETA_DEPLOY_VALUE"
    [[ "$stored" == "$provider" ]] || { msg_error "Provider mismatch in $file"; return 1; }
    case "$provider" in
        github-pages)
            zeta_deploy_read_file "$file" repository || return 1; repo="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read_file "$file" branch || return 1; branch="$ZETA_DEPLOY_VALUE"
            zeta_deploy_valid_repo "$repo" && zeta_deploy_valid_branch "$branch" || { msg_error 'Invalid GitHub Pages destination'; return 1; }
            ;;
        cloudflare-pages)
            zeta_deploy_read_file "$file" project || return 1; project="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read_file "$file" account || return 1; account="$ZETA_DEPLOY_VALUE"
            zeta_deploy_valid_slug "$project" && [[ -z "$account" || "$account" =~ ^[a-fA-F0-9]{32}$ ]] || { msg_error 'Invalid Cloudflare destination'; return 1; }
            ;;
        *) return 1 ;;
    esac
}
zeta_deploy_setup() {
    local site="$1" provider choice repo branch project account existing old cfg tmp
    require_site_slug "$site" || return 1
    find_site_config "$SITES_DIR/$site" >/dev/null || return 1
    [[ -t 0 ]] || { msg_error 'Setup requires an interactive terminal.'; return 1; }
    printf '\nZETA / Configure provider for %s\n' "$site"
    printf '  Existing targets: %s\n' "$(zeta_deploy_summary "$site")"
    printf '  [1] GitHub Pages\n  [2] Cloudflare Pages\n'
    read -rp 'Provider to add or update [1]: ' choice
    case "$choice" in ''|1) provider=github-pages ;; 2) provider=cloudflare-pages ;; *) msg_error 'Unknown provider'; return 1 ;; esac
    repo='';branch='';project='';account=''
    if existing=$(zeta_deploy_resolve_file "$site" "$provider"); then
        zeta_deploy_read_file "$existing" repository && repo="$ZETA_DEPLOY_VALUE"
        zeta_deploy_read_file "$existing" branch && branch="$ZETA_DEPLOY_VALUE"
        zeta_deploy_read_file "$existing" project && project="$ZETA_DEPLOY_VALUE"
        zeta_deploy_read_file "$existing" account && account="$ZETA_DEPLOY_VALUE"
    fi
    if [[ "$provider" == github-pages ]]; then
        read -rp "GitHub repository (owner/repository) [$repo]: " choice; repo="${choice:-$repo}"
        read -rp "Publishing branch [${branch:-gh-pages}]: " choice; branch="${choice:-${branch:-gh-pages}}"
        zeta_deploy_valid_repo "$repo" && zeta_deploy_valid_branch "$branch" || { msg_error 'Invalid repository or branch'; return 1; }
    else
        read -rp "Cloudflare Pages project [$project]: " choice; project="${choice:-$project}"
        read -rp 'Cloudflare account ID (optional): ' choice; account="${choice:-$account}"
        zeta_deploy_valid_slug "$project" && [[ -z "$account" || "$account" =~ ^[a-fA-F0-9]{32}$ ]] || { msg_error 'Invalid Cloudflare project or account'; return 1; }
    fi
    printf '\nProvider: %s\n' "$provider"
    if [[ "$provider" == github-pages ]]; then printf 'Destination: %s (%s)\n' "$repo" "$branch"
    else printf 'Project: %s\n' "$project"; fi
    printf 'Other configured providers will remain unchanged.\n'
    read -rp 'Save this provider? [y/N]: ' choice
    [[ "$choice" =~ ^[YySs] ]] || { msg_info 'Configuration unchanged'; return 0; }
    cfg=$(zeta_deploy_target_file "$site" "$provider")
    mkdir -p "$(dirname "$cfg")" || return 1
    tmp="$cfg.tmp.$$"
    (umask 077; printf 'provider=%s\nrepository=%s\nbranch=%s\nproject=%s\naccount=%s\n' "$provider" "$repo" "$branch" "$project" "$account" > "$tmp") || return 1
    mv -f -- "$tmp" "$cfg" || { rm -f -- "$tmp"; return 1; }
    msg_success "Saved $provider for $site. Targets: $(zeta_deploy_summary "$site")"
}
zeta_deploy_status() {
    local site="$1" provider file repo branch project targets=()
    require_site_slug "$site" || return 1
    mapfile -t targets < <(zeta_deploy_targets "$site")
    (("${#targets[@]}" > 0)) || { msg_warn "Not configured. Run: ./zeta.sh deploy setup $site"; return 1; }
    printf 'Site: %s | %s configured\n' "$site" "${#targets[@]}"
    for provider in "${targets[@]}"; do
        zeta_deploy_validate "$site" "$provider" || return 1
        file=$(zeta_deploy_resolve_file "$site" "$provider") || return 1
        if [[ "$provider" == github-pages ]]; then
            zeta_deploy_read_file "$file" repository; repo="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read_file "$file" branch; branch="$ZETA_DEPLOY_VALUE"
            printf '  GitHub Pages     %s (%s)\n' "$repo" "$branch"
        else
            zeta_deploy_read_file "$file" project; project="$ZETA_DEPLOY_VALUE"
            printf '  Cloudflare Pages %s\n' "$project"
        fi
    done
}
zeta_deploy_choose() {
    local site="$1" requested="$2" available=() selection answer provider index
    ZETA_DEPLOY_SELECTED=()
    mapfile -t available < <(zeta_deploy_targets "$site")
    (("${#available[@]}" > 0)) || { msg_error "No destinations. Configure one: ./zeta.sh deploy setup $site"; return 1; }
    if [[ -z "$requested" && "${#available[@]}" -gt 1 ]]; then
        if [[ ! -t 0 ]]; then msg_error 'Multiple targets: specify all or a provider explicitly.'; return 1; fi
        printf 'Select deployment targets (default: all):\n'
        for index in "${!available[@]}"; do printf '  [%s] %s\n' "$((index+1))" "${available[index]}"; done
        read -rp 'Providers [all / 1,2 / 1]: ' requested
    fi
    case "$requested" in
        ''|all) ZETA_DEPLOY_SELECTED=("${available[@]}") ;;
        *)
            local parts=()
            IFS=',' read -r -a parts <<< "$requested"
            (("${#parts[@]}" > 0)) || return 1
            for selection in "${parts[@]}"; do
                case "$selection" in
                    github-pages|cloudflare-pages) provider="$selection" ;;
                    *)
                        if [[ "$selection" =~ ^[1-9][0-9]*$ ]] && (( selection <= "${#available[@]}" )); then provider="${available[selection-1]}"
                        else msg_error "Invalid target: $selection"; return 1; fi ;;
                esac
                local found=false item
                for item in "${available[@]}"; do [[ "$item" == "$provider" ]] && found=true; done
                [[ "$found" == true ]] || { msg_error "Target not configured: $provider"; return 1; }
                found=false
                for item in "${ZETA_DEPLOY_SELECTED[@]}"; do [[ "$item" == "$provider" ]] && found=true; done
                [[ "$found" == true ]] || ZETA_DEPLOY_SELECTED+=("$provider")
            done
            ;;
    esac
    (("${#ZETA_DEPLOY_SELECTED[@]}" > 0)) || { msg_error 'No deployment targets selected'; return 1; }
    for provider in "${ZETA_DEPLOY_SELECTED[@]}"; do zeta_deploy_validate "$site" "$provider" || return 1; done
}
zeta_deploy_safety() {
    local output="$1" bad
    [[ -s "$output/index.html" && ! -L "$output" ]] || { msg_error "Missing index.html or unsafe output: $output"; return 1; }
    if find "$output" -mindepth 1 -name .git -print -quit | grep -q .; then msg_error 'Embedded Git metadata'; return 1; fi
    if find "$output" -type l -print -quit | grep -q .; then msg_error 'Output contains symlinks'; return 1; fi
    bad=$(find "$output" -type f \( -iname '*.md' -o -name config.yaml -o -name deploy.conf -o -name '.env*' -o -name '*.pem' -o -name '*.key' \) -print -quit)
    [[ -z "$bad" ]] || { msg_error "Cannot publish source or secret: $bad"; return 1; }
}
zeta_deploy_provider() {
    local site="$1" provider="$2" output="$3" file repo branch project account remote tmp rc
    file=$(zeta_deploy_resolve_file "$site" "$provider") || return 1
    case "$provider" in
        github-pages)
            command_exists git || { msg_error 'Git is required'; return 1; }
            zeta_deploy_read_file "$file" repository; repo="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read_file "$file" branch; branch="$ZETA_DEPLOY_VALUE"
            remote="https://github.com/$repo.git"
            tmp=$(mktemp -d) || return 1
            if ! git clone -q --depth 1 --branch "$branch" "$remote" "$tmp"; then
                rm -rf -- "$tmp"; msg_error "Could not clone $repo ($branch)"; return 1
            fi
            (cd "$tmp" && git ls-files -z | xargs -0 -r rm -f --) || { rm -rf -- "$tmp"; return 1; }
            cp -a "$output/." "$tmp/" || { rm -rf -- "$tmp"; return 1; }
            : > "$tmp/.nojekyll"
            (cd "$tmp" && git add -A && if ! git diff --cached --quiet; then
                git -c user.name='Zeta Deploy' -c user.email='zeta-deploy@users.noreply.github.com' commit -qm "Deploy $site" && git push origin "$branch"
            else printf 'No changes for GitHub Pages\n'; fi)
            rc=$?; rm -rf -- "$tmp"; return "$rc" ;;
        cloudflare-pages)
            command_exists wrangler || { msg_error 'Wrangler is required (wrangler login)'; return 1; }
            zeta_deploy_read_file "$file" project; project="$ZETA_DEPLOY_VALUE"
            zeta_deploy_read_file "$file" account; account="$ZETA_DEPLOY_VALUE"
            if [[ -n "$account" ]]; then CLOUDFLARE_ACCOUNT_ID="$account" wrangler pages deploy "$output" --project-name "$project"
            else wrangler pages deploy "$output" --project-name "$project"; fi ;;
        *) return 1 ;;
    esac
}
zeta_deploy_run() {
    local site="$1" dry="${2:-false}" requested="${3:-}" cfg output_rel output reply provider failures=0 successes=0
    local selected=()
    require_site_slug "$site" || return 1
    cfg=$(find_site_config "$SITES_DIR/$site") || return 1
    zeta_deploy_choose "$site" "$requested" || return 1
    selected=("${ZETA_DEPLOY_SELECTED[@]}")
    output_rel=$(get_site_yaml_prop "$cfg" build output_dir public)
    is_safe_relative_dir "$output_rel" || { msg_error 'Unsafe build output'; return 1; }
    output="$SITES_DIR/$site/$output_rel"
    printf '\nZETA / Deploy %s\n' "$site"
    printf '  Selected: %s\n' "${selected[*]}"
    if [[ "$dry" != true ]]; then
        build_site "$site" || return 1
        diagnose_site "$site" || return 1
    fi
    zeta_deploy_safety "$output" || return 1
    if [[ "$dry" == true ]]; then
        printf 'DRY RUN: no uploads or remote changes. Existing output files:\n'
        find "$output" -type f | sed "s|^$output/||" | sort
        return 0
    fi
    if [[ -t 0 ]]; then
        read -rp 'Publish to the selected destinations? [y/N]: ' reply
        [[ "$reply" =~ ^[YySs] ]] || { msg_info 'Cancelled'; return 0; }
    fi
    for provider in "${selected[@]}"; do
        print_section "Publishing to $provider"
        if zeta_deploy_provider "$site" "$provider" "$output"; then
            msg_success "$provider: published"; ((successes+=1))
        else
            msg_error "$provider: failed"; ((failures+=1))
        fi
    done
    printf '\nDeployment summary: %s succeeded, %s failed (%s selected).\n' "$successes" "$failures" "${#selected[@]}"
    ((failures==0))
}
