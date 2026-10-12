# shellcheck disable=SC2034

pandoc_install_hint() {
    if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
        echo "Install Pandoc with Homebrew: brew install pandoc"
        return 0
    fi

    if command_exists apt-get; then
        echo "Install Pandoc: sudo apt-get install pandoc"
    elif command_exists dnf; then
        echo "Install Pandoc: sudo dnf install pandoc"
    elif command_exists pacman; then
        echo "Install Pandoc: sudo pacman -S pandoc"
    elif command_exists zypper; then
        echo "Install Pandoc: sudo zypper install pandoc"
    elif command_exists apk; then
        echo "Install Pandoc: sudo apk add pandoc"
    else
        echo "Install Pandoc from https://pandoc.org/installing.html"
    fi
}

ensure_pandoc_installed() {
    if command_exists pandoc; then
        [[ "$VERBOSE" == true ]] && msg_debug "Pandoc: $(pandoc --version | head -n 1)"
        return 0
    fi

    msg_error "Pandoc is required to build a site, but it is not installed."
    pandoc_install_hint >&2
    return 1
}


pandoc_highlight_option() {
    command_exists pandoc || return 1

    local help_text
    help_text=$(pandoc --help 2>/dev/null || true)

    # Newer Pandoc versions prefer --syntax-highlighting. Older releases use
    # --highlight-style. Capability detection avoids deprecation warnings.
    if grep -q -- '--syntax-highlighting' <<<"$help_text"; then
        printf '%s\n' '--syntax-highlighting'
        return 0
    fi

    if grep -q -- '--highlight-style' <<<"$help_text"; then
        printf '%s\n' '--highlight-style'
        return 0
    fi

    return 1
}


pandoc_markdown_reader() {
    command_exists pandoc || {
        printf '%s\n' 'markdown'
        return 0
    }

    # Pandoc Markdown already enables tables, fenced code, footnotes,
    # definition lists, task lists and YAML metadata. Bare URL autolinking is
    # useful for blog authoring but is not enabled by default.
    if pandoc --list-extensions=markdown 2>/dev/null | grep -Eq '^[+-]autolink_bare_uris$'; then
        printf '%s\n' 'markdown+autolink_bare_uris'
    else
        printf '%s\n' 'markdown'
    fi
}
