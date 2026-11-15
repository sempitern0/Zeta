# Protect generated output against edits made directly inside public/.
# The baseline lives outside public/ and tracks the exact last successful build.
zeta_build_manifest() {
    local directory="$1" target="$2" file path hash relative
    : > "$target" || return 1
    [[ -d "$directory" ]] || return 0
    while IFS= read -r file; do
        relative="${file#"$directory"/}"
        if [[ -L "$file" ]]; then
            hash="link:$(readlink "$file")"
        elif command -v sha256sum >/dev/null 2>&1; then
            hash=$(sha256sum < "$file") || return 1
            hash="${hash%% *}"
        elif command -v shasum >/dev/null 2>&1; then
            hash=$(shasum -a 256 < "$file") || return 1
            hash="${hash%% *}"
        else
            msg_error "SHA-256 requires sha256sum or shasum."
            return 1
        fi
        printf '%s\t%s\n' "$hash" "$relative" >> "$target"
    done < <(LC_ALL=C find "$directory" \( -type f -o -type l \) -print | LC_ALL=C sort)
}

zeta_build_output_guard() {
    local final="$1" manifest="$2" site_slug="$3" probe="${4}"
    [[ -e "$final" || -L "$final" ]] || return 0
    if [[ -L "$final" || ! -d "$final" ]]; then
        msg_error "Build destination is not a regular directory: $final"
        return 1
    fi
    zeta_build_manifest "$final" "$probe" || return 1
    if [[ -f "$manifest" ]] && cmp -s "$probe" <(tr -d '\015' < "$manifest"); then
        return 0
    fi
    # A pre-existing directory with no manifest is unverified, never assumed safe.
    if [[ ! -s "$probe" && ! -f "$manifest" ]]; then return 0; fi
    if [[ "${FORCE:-false}" == true ]]; then
        msg_warn "Replacing modified/untracked output for '$site_slug' (--force)."
        return 0
    fi
    msg_warn "Untracked or manually changed files detected in '$final'."
    msg_warn "The build will replace that directory. Put permanent customizations in sites/$site_slug/styles/ or assets/."
    if [[ -t 0 && -t 1 ]]; then
        local answer
        read -r -p "Replace this output and discard its local changes? [y/N] " answer || return 1
        if [[ "$answer" == y || "$answer" == Y || "$answer" == yes || "$answer" == YES ]]; then return 0; fi
    fi
    msg_error "Build canceled: existing output preserved. Use --force to replace it."
    return 1
}
