#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155,SC2154

require_site_slug() {
    local site_slug="$1"
    if ! is_valid_site_slug "$site_slug"; then
        msg_error "Invalid site slug: '${site_slug}'."
        return 1
    fi
}

get_all_sites() {
    [[ -d "$SITES_DIR" ]] || return 0

    local dir
    for dir in "${SITES_DIR}"/*/; do
        [[ -d "$dir" && ! -L "$dir" ]] || continue
        local site_name
        site_name=$(basename "$dir")
        if is_valid_site_slug "$site_name" && [[ -f "${dir}/config.yaml" || -f "${dir}/config.yml" ]]; then
            printf '%s\n' "$site_name"
        fi
    done
}

site_post_count() {
    local site_slug="$1"
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir" 2>/dev/null) || { echo 0; return 0; }

    local content_rel
    content_rel=$(get_site_yaml_prop "$config_file" "build" "content_dir" "posts")
    is_safe_relative_dir "$content_rel" || { echo 0; return 0; }

    if [[ -d "${site_dir}/${content_rel}" ]]; then
        find "${site_dir}/${content_rel}" -type f -name '*.md' -print | wc -l | tr -d ' '
    else
        echo 0
    fi
}

select_site_interactive() {
    local sites=()
    readarray -t sites < <(get_all_sites)

    if [[ ${#sites[@]} -eq 0 ]]; then
        msg_warn "No sites found in '${SITES_DIR}'."
        return 1
    fi

    echo "" >&2
    local i=1
    local site
    for site in "${sites[@]}"; do
        printf '  [%d] %s\n' "$i" "$site" >&2
        ((i++))
    done
    echo "" >&2

    local choice
    read -rp "Select site [1-${#sites[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#sites[@]} )); then
        printf '%s\n' "${sites[$((choice - 1))]}"
        return 0
    fi

    msg_error "Invalid site selection."
    return 1
}

list_sites() {
    local sites=()
    readarray -t sites < <(get_all_sites)

    if [[ ${#sites[@]} -eq 0 ]]; then
        msg_info "No sites in the local workspace."
        return 0
    fi

    printf '\n%-24s %-7s %-10s %s\n' "SITE" "POSTS" "PUBLIC" "TITLE"
    printf '%-24s %-7s %-10s %s\n' "------------------------" "-----" "--------" "------------------------------"

    local site
    for site in "${sites[@]}"; do
        local site_dir="${SITES_DIR}/${site}"
        local config_file title output_rel public_state
        config_file=$(find_site_config "$site_dir")
        title=$(get_site_yaml_prop "$config_file" "site" "title" "$site")
        output_rel=$(get_site_yaml_prop "$config_file" "build" "output_dir" "public")
        if [[ -f "${site_dir}/${output_rel}/index.html" ]]; then
            public_state="built"
        else
            public_state="missing"
        fi
        printf '%-24s %-7s %-10s %s\n' "$site" "$(site_post_count "$site")" "$public_state" "$title"
    done
    echo ""
}

yaml_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    printf '"%s"' "$value"
}

write_site_config() {
    local config_file="$1"
    local site_title="$2"
    local site_desc="$3"
    local site_author="$4"
    local site_lang="$5"
    local site_url="$6"
    local site_theme="$7"
    local pandoc_theme="$8"
    local content_rel="${9:-posts}"
    local output_rel="${10:-public}"

    cat > "$config_file" <<EOF_CONFIG
site:
  title: $(yaml_quote "$site_title")
  description: $(yaml_quote "$site_desc")
  author: $(yaml_quote "$site_author")
  language: $(yaml_quote "$site_lang")
  url: $(yaml_quote "$site_url")

theme:
  name: $(yaml_quote "$site_theme")
  pandoc_theme: $(yaml_quote "$pandoc_theme")

build:
  content_dir: $(yaml_quote "$content_rel")
  output_dir: $(yaml_quote "$output_rel")
EOF_CONFIG
}

available_themes() {
    [[ -d "$TEMPLATES_DIR" ]] || return 0
    local dir name
    for dir in "${TEMPLATES_DIR}"/*/; do
        [[ -d "$dir" ]] || continue
        name=$(basename "$dir")
        [[ "$name" == "common" ]] && continue
        [[ -f "${dir}/index.html" && -f "${dir}/article.html" ]] || continue
        echo "$name"
    done
}

choose_theme_interactive() {
    local current="${1:-zen}"
    local themes=()
    readarray -t themes < <(available_themes)

    if [[ ${#themes[@]} -eq 0 ]]; then
        echo "$current"
        return 0
    fi

    echo "" >&2
    echo "Available themes:" >&2
    local i=1 theme default_index=1
    for theme in "${themes[@]}"; do
        [[ "$theme" == "$current" ]] && default_index=$i
        printf '  [%d] %s%s\n' "$i" "$theme" "$([[ "$theme" == "$current" ]] && echo ' (current)' || true)" >&2
        ((i++))
    done

    local choice
    read -rp "Theme [${default_index}]: " choice
    choice="${choice:-$default_index}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#themes[@]} )); then
        echo "${themes[$((choice - 1))]}"
    else
        msg_warn "Invalid theme. Keeping '${current}'."
        echo "$current"
    fi
}

choose_highlight_interactive() {
    local current="${1:-zenburn}"
    local styles=()

    if command_exists pandoc; then
        readarray -t styles < <(pandoc --list-highlight-styles 2>/dev/null || true)
    fi
    [[ ${#styles[@]} -gt 0 ]] || styles=(zenburn pygments kate monochrome breezedark espresso haddock tango)

    echo "" >&2
    echo "Pandoc syntax highlight styles:" >&2
    local i=1 style default_index=1
    for style in "${styles[@]}"; do
        [[ "${style,,}" == "${current,,}" ]] && default_index=$i
        printf '  [%d] %s%s\n' "$i" "$style" "$([[ "${style,,}" == "${current,,}" ]] && echo ' (current)' || true)" >&2
        ((i++))
    done

    local choice
    read -rp "Highlight style [${default_index}]: " choice
    choice="${choice:-$default_index}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#styles[@]} )); then
        echo "${styles[$((choice - 1))]}"
    else
        msg_warn "Invalid style. Keeping '${current}'."
        echo "$current"
    fi
}


create_example_posts() {
    local site_slug="$1"
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || return 1

    local content_rel site_author
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir posts)
    site_author=$(get_site_yaml_prop "$config_file" site author "${USER:-Author}")
    local content_dir="${site_dir}/${content_rel}"
    mkdir -p "$content_dir"

    local today year
    today=$(date +%Y-%m-%d)
    year=$(date +%Y)

    cat > "${content_dir}/${today}-zeta-markdown-showcase.md" <<EOF_SAMPLE
---
title: "Zeta Markdown Showcase"
author: $(yaml_quote "$site_author")
date: $(yaml_quote "$today")
description: "Headings, lists, tables, links, quotes and inline formatting."
slug: "zeta-markdown-showcase"
tags:
  - "zeta"
  - "markdown"
  - "demo"
---

This post is generated automatically so you can validate the selected theme.

## Text and links

Normal text, **bold**, *italic*, ~~strikethrough~~ and \`inline code\`.

- Unordered item
- Another item
  - Nested item

1. Ordered item
2. Another ordered item

> A blockquote helps verify spacing, contrast and typography.

[Visit the Pandoc project](https://pandoc.org/).

## Table

| Feature | Status | Notes |
| --- | --- | --- |
| Markdown | OK | Source content |
| HTML5 | OK | Generated by Pandoc |
| CSS | OK | Common + theme + site layers |
| Tables | OK | Responsive semantic table |

Table: Pipe table with a caption

## Task list

- [x] Markdown parsed
- [x] HTML generated
- [ ] Replace this demo with your own content

## Definition-style content

Term
: A compact definition rendered from Pandoc Markdown.

## Footnote

Pandoc also supports footnotes without extra plugins.[^zeta]

[^zeta]: This footnote is rendered by Pandoc and styled by the common Markdown layer.

## Grid table

+----------------------+----------------------+
| Input                | Output               |
+======================+======================+
| Markdown source      | Semantic HTML5       |
+----------------------+----------------------+
| Fenced code blocks   | Highlighted code     |
+----------------------+----------------------+

---

End of the first Zeta example post.
EOF_SAMPLE

    cat > "${content_dir}/${today}-zeta-code-showcase.md" <<EOF_SAMPLE
---
title: "Zeta Code Showcase"
author: $(yaml_quote "$site_author")
date: $(yaml_quote "$today")
description: "Multiple fenced code blocks to validate Pandoc syntax highlighting."
slug: "zeta-code-showcase"
tags:
  - "code"
  - "pandoc"
  - "demo"
---

Use this post to confirm syntax highlighting, horizontal scrolling and code readability.

## Bash

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

for file in posts/*.md; do
    printf 'Building %s\\n' "\$file"
done
\`\`\`

## Python

\`\`\`python
from pathlib import Path

posts = sorted(Path("posts").glob("*.md"))
print(f"{len(posts)} post(s)")
\`\`\`

## JavaScript

\`\`\`javascript
const posts = ["first.md", "second.md"];
posts.forEach((post) => console.log(post));
\`\`\`

## YAML

\`\`\`yaml
site:
  title: "Zeta"
build:
  content_dir: "posts"
  output_dir: "public"
\`\`\`

## JSON

\`\`\`json
{
  "generator": "Zeta",
  "static": true,
  "dependencies": ["bash", "pandoc"]
}
\`\`\`

## CSS

\`\`\`css
:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 3px;
}
\`\`\`

## HTML

\`\`\`html
<main id="content">
  <article>
    <h1>Accessible static HTML</h1>
  </article>
</main>
\`\`\`
EOF_SAMPLE

    msg_success "Created 2 example Markdown posts in ${content_rel}/."
}

font_download() {
    local url="$1"
    local destination="$2"

    mkdir -p "$(dirname "$destination")"

    if command_exists curl; then
        curl -fsSL --retry 2 --connect-timeout 10 "$url" -o "$destination"
    elif command_exists wget; then
        wget -qO "$destination" "$url"
    else
        msg_error "Installing web fonts requires curl or wget."
        return 1
    fi
}

font_cache_root() {
    printf '%s\n' "${CURRENT_DIR}/.zeta-cache/fonts"
}

font_cache_is_complete() {
    local cache_dir="$1"
    shift

    local required_file
    for required_file in "$@"; do
        [[ -s "${cache_dir}/${required_file}" ]] || return 1
    done

    return 0
}

populate_font_cache() {
    local font_id="$1"
    local license_url="$2"
    shift 2
    local -a faces=("$@")

    local cache_root cache_dir staging
    cache_root=$(font_cache_root)
    cache_dir="${cache_root}/${font_id}"
    staging="${cache_root}/.${font_id}.download-${BASHPID:-$$}"

    local -a required_files=("LICENSE.txt")
    local face filename font_style font_weight url

    for face in "${faces[@]}"; do
        IFS='|' read -r filename font_style font_weight url <<< "$face"
        required_files+=("$filename")
    done

    if font_cache_is_complete "$cache_dir" "${required_files[@]}"; then
        msg_info "Font cache hit: ${font_id}"
        return 0
    fi

    msg_info "Font cache miss: downloading ${font_id} once for this checkout."

    rm -rf -- "$staging"
    mkdir -p "$staging"

    for face in "${faces[@]}"; do
        IFS='|' read -r filename font_style font_weight url <<< "$face"
        if ! font_download "$url" "${staging}/${filename}"; then
            msg_error "Could not download ${filename}."
            rm -rf -- "$staging"
            return 1
        fi
    done

    if ! font_download "$license_url" "${staging}/LICENSE.txt"; then
        msg_error "Could not download the font license."
        rm -rf -- "$staging"
        return 1
    fi

    if ! font_cache_is_complete "$staging" "${required_files[@]}"; then
        msg_error "Downloaded font cache is incomplete for ${font_id}."
        rm -rf -- "$staging"
        return 1
    fi

    mkdir -p "$cache_root"
    rm -rf -- "$cache_dir"
    mv "$staging" "$cache_dir"

    msg_success "Cached ${font_id} in .zeta-cache/fonts/."
}

install_open_font() {
    local site_slug="$1"
    local font_key="$2"

    require_site_slug "$site_slug" || return 1

    local site_dir="${SITES_DIR}/${site_slug}"
    [[ -d "$site_dir" ]] || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    local font_id family license_url
    local -a faces=()

    case "$font_key" in
        cascadia)
            font_id="CascadiaCode"
            family="Cascadia Code"
            license_url="https://raw.githubusercontent.com/microsoft/cascadia-code/main/LICENSE"
            faces=(
                "CascadiaCode.woff2|normal|200 700|https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/CascadiaCode/CascadiaCode.woff2"
                "CascadiaCodeItalic.woff2|italic|200 700|https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/CascadiaCode/CascadiaCodeItalic.woff2"
            )
            ;;
        jetbrains)
            font_id="JetBrainsMono"
            family="JetBrains Mono"
            license_url="https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt"
            faces=(
                "JetBrainsMono-Regular.woff2|normal|400|https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-Regular.woff2"
                "JetBrainsMono-Italic.woff2|italic|400|https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-Italic.woff2"
                "JetBrainsMono-Bold.woff2|normal|700|https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-Bold.woff2"
                "JetBrainsMono-BoldItalic.woff2|italic|700|https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-BoldItalic.woff2"
            )
            ;;
        fira)
            font_id="FiraCode"
            family="Fira Code"
            license_url="https://raw.githubusercontent.com/tonsky/FiraCode/master/LICENSE"
            faces=(
                "FiraCode-Regular.woff2|normal|400|https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/FiraCode/FiraCode-Regular.woff2"
                "FiraCode-Bold.woff2|normal|700|https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/FiraCode/FiraCode-Bold.woff2"
            )
            ;;
        ibm-plex)
            font_id="IBMPlexMono"
            family="IBM Plex Mono"
            license_url="https://raw.githubusercontent.com/IBM/plex/master/LICENSE.txt"
            faces=(
                "IBMPlexMono-Regular.woff2|normal|400|https://raw.githubusercontent.com/IBM/plex/master/packages/plex-mono/fonts/complete/woff2/IBMPlexMono-Regular.woff2"
                "IBMPlexMono-Italic.woff2|italic|400|https://raw.githubusercontent.com/IBM/plex/master/packages/plex-mono/fonts/complete/woff2/IBMPlexMono-Italic.woff2"
                "IBMPlexMono-Bold.woff2|normal|700|https://raw.githubusercontent.com/IBM/plex/master/packages/plex-mono/fonts/complete/woff2/IBMPlexMono-Bold.woff2"
                "IBMPlexMono-BoldItalic.woff2|italic|700|https://raw.githubusercontent.com/IBM/plex/master/packages/plex-mono/fonts/complete/woff2/IBMPlexMono-BoldItalic.woff2"
            )
            ;;
        source-code)
            font_id="SourceCodePro"
            family="Source Code Pro"
            license_url="https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/LICENSE.md"
            faces=(
                "SourceCodePro-Regular.woff2|normal|400|https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/WOFF2/TTF/SourceCodePro-Regular.ttf.woff2"
                "SourceCodePro-Italic.woff2|italic|400|https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/WOFF2/TTF/SourceCodePro-It.ttf.woff2"
                "SourceCodePro-Bold.woff2|normal|700|https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/WOFF2/TTF/SourceCodePro-Bold.ttf.woff2"
                "SourceCodePro-BoldItalic.woff2|italic|700|https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/WOFF2/TTF/SourceCodePro-BoldIt.ttf.woff2"
            )
            ;;
        *)
            msg_error "Unknown font key: '${font_key}'."
            return 1
            ;;
    esac

    print_section "Install web font: ${family}"

    populate_font_cache "$font_id" "$license_url" "${faces[@]}" || return 1

    local cache_dir
    cache_dir="$(font_cache_root)/${font_id}"

    local staging="${site_dir}/.zeta-font-${BASHPID:-$$}"
    local stage_font_dir="${staging}/assets/fonts/${font_id}"
    local stage_styles="${staging}/styles"

    rm -rf -- "$staging"
    mkdir -p "$stage_font_dir" "$stage_styles"

    cp -a "${cache_dir}/." "$stage_font_dir/"

    local css_file="${stage_styles}/90-font.css"
    : > "$css_file"

    local face filename font_style font_weight url
    for face in "${faces[@]}"; do
        IFS='|' read -r filename font_style font_weight url <<< "$face"
        cat >> "$css_file" <<EOF_FONT_FACE
@font-face {
  font-family: "${family}";
  src: url("../assets/fonts/${font_id}/${filename}") format("woff2");
  font-style: ${font_style};
  font-weight: ${font_weight};
  font-display: swap;
}

EOF_FONT_FACE
    done

    cat >> "$css_file" <<EOF_FONT_VARS
:root {
  --font-mono: "${family}", ui-monospace, "SFMono-Regular", Consolas, "Liberation Mono", monospace;
  --font-sans: "${family}", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
EOF_FONT_VARS

    mkdir -p "${site_dir}/assets" "${site_dir}/styles"
    rm -rf -- "${site_dir}/assets/fonts"
    rm -f -- "${site_dir}/styles"/90-font*.css
    cp -a "${staging}/assets/fonts" "${site_dir}/assets/fonts"
    cp "$css_file" "${site_dir}/styles/90-font.css"
    rm -rf -- "$staging"

    msg_success "${family} enabled for '${site_slug}'."
}


remove_site_font() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1

    local site_dir="${SITES_DIR}/${site_slug}"
    [[ -d "$site_dir" ]] || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    rm -rf -- "${site_dir}/assets/fonts"
    rm -f -- "${site_dir}/styles"/90-font*.css
    msg_success "Custom web font removed. '${site_slug}' will use the theme fallback stack."
}

manage_site_fonts() {
    local site_slug="$1"

    echo ""
    echo -e "${boldWhite}Open web fonts${endColour}"
    echo -e "  ${boldGreen}[1]${endColour} Cascadia Code    ${grayColour}(OFL; variable regular + italic)${endColour}"
    echo -e "  ${boldGreen}[2]${endColour} JetBrains Mono  ${grayColour}(OFL; regular/italic/bold)${endColour}"
    echo -e "  ${boldGreen}[3]${endColour} Fira Code        ${grayColour}(OFL; programming ligatures)${endColour}"
    echo -e "  ${boldGreen}[4]${endColour} IBM Plex Mono    ${grayColour}(OFL; regular/italic/bold)${endColour}"
    echo -e "  ${boldGreen}[5]${endColour} Source Code Pro  ${grayColour}(OFL; regular/italic/bold)${endColour}"
    echo -e "  ${boldYellow}[6]${endColour} Use theme defaults / remove custom font"
    echo -e "  ${boldGreen}[0]${endColour} Back"
    echo ""

    local option action_rc=0
    read -rp "$(printf '%b' "${boldCyan}Zeta fonts ❯ ${endColour}")" option

    case "${option,,}" in
        1) install_open_font "$site_slug" cascadia || action_rc=$? ;;
        2) install_open_font "$site_slug" jetbrains || action_rc=$? ;;
        3) install_open_font "$site_slug" fira || action_rc=$? ;;
        4) install_open_font "$site_slug" ibm-plex || action_rc=$? ;;
        5) install_open_font "$site_slug" source-code || action_rc=$? ;;
        6) remove_site_font "$site_slug" || action_rc=$? ;;
        0|b|back) return 0 ;;
        *)
            msg_warn "Invalid font option: '${option}'."
            return 1
            ;;
    esac

    (( action_rc == 0 )) || return "$action_rc"

    msg_info "Regenerating public/ so the font change is immediately visible."
    build_site "$site_slug" && update_sites_index
}

theme_exists() {
    local theme="$1"
    [[ -n "$theme" ]] || return 1
    [[ -d "${TEMPLATES_DIR}/${theme}" ]] || return 1
    [[ -f "${TEMPLATES_DIR}/${theme}/index.html" ]] || return 1
    [[ -f "${TEMPLATES_DIR}/${theme}/article.html" ]] || return 1
    [[ -f "${TEMPLATES_DIR}/${theme}/post_link.html" ]] || return 1
}

highlight_style_exists() {
    local style="$1"
    [[ -n "$style" ]] || return 1

    if ! command_exists pandoc; then
        return 0
    fi

    pandoc --list-highlight-styles 2>/dev/null | grep -Fxiq -- "$style"
}

change_site_appearance() {
    local site_slug="$1"
    local requested_theme="${2:-}"
    local requested_highlight="${3:-}"

    require_site_slug "$site_slug" || return 1

    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    local title desc author lang url theme highlight content_rel output_rel
    title=$(get_site_yaml_prop "$config_file" site title "$site_slug")
    desc=$(get_site_yaml_prop "$config_file" site description "")
    author=$(get_site_yaml_prop "$config_file" site author "${USER:-Author}")
    lang=$(get_site_yaml_prop "$config_file" site language "en")
    url=$(get_site_yaml_prop "$config_file" site url "https://example.com")
    theme=$(get_site_yaml_prop "$config_file" theme name "zen")
    highlight=$(get_site_yaml_prop "$config_file" theme pandoc_theme "zenburn")
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir "posts")
    output_rel=$(get_site_yaml_prop "$config_file" build output_dir "public")

    print_section "Appearance: ${site_slug}"

    if [[ -n "$requested_theme" ]]; then
        if ! theme_exists "$requested_theme"; then
            msg_error "Unknown theme: '${requested_theme}'."
            return 1
        fi
        theme="$requested_theme"
    else
        theme=$(choose_theme_interactive "$theme")
    fi

    if [[ -n "$requested_highlight" ]]; then
        if ! highlight_style_exists "$requested_highlight"; then
            msg_error "Unknown Pandoc highlight style: '${requested_highlight}'."
            return 1
        fi
        highlight="$requested_highlight"
    else
        highlight=$(choose_highlight_interactive "$highlight")
    fi

    write_site_config "$config_file" "$title" "$desc" "$author" "$lang" "$url" \
        "$theme" "$highlight" "$content_rel" "$output_rel"

    msg_success "Appearance updated: theme='${theme}', highlight='${highlight}'."
    msg_info "Regenerating public/ with the new appearance."
    build_site "$site_slug" && update_sites_index
}



hex_to_rgb() {
    local hex="${1#\#}"
    [[ "$hex" =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
    printf '%d %d %d\n' \
        "$((16#${hex:0:2}))" \
        "$((16#${hex:2:2}))" \
        "$((16#${hex:4:2}))"
}

print_color_swatch() {
    local label="$1"
    local color="$2"
    local rgb r g b

    if [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]] && rgb=$(hex_to_rgb "$color"); then
        read -r r g b <<< "$rgb"
        if [[ -z "${NO_COLOR:-}" ]]; then
            printf '  %-24s \033[48;2;%d;%d;%dm      \033[0m  %s\n' "$label" "$r" "$g" "$b" "$color"
        else
            printf '  %-24s %s\n' "$label" "$color"
        fi
    else
        printf '  %-24s %s\n' "$label" "$color"
    fi
}

show_theme_palette() {
    local theme_name="$1"
    local theme_dir="${TEMPLATES_DIR}/${theme_name}"
    local css_file line name color found=false

    echo ""
    echo -e "${boldWhite}Theme palette: ${theme_name}${endColour}"

    while IFS= read -r css_file; do
        while IFS= read -r line; do
            name=$(sed -E 's/^[[:space:]]*--([^:]+):[[:space:]]*(#[0-9A-Fa-f]{6}).*/\1/' <<< "$line")
            color=$(sed -E 's/^[[:space:]]*--[^:]+:[[:space:]]*(#[0-9A-Fa-f]{6}).*/\1/' <<< "$line")
            [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
            print_color_swatch "--${name}" "$color"
            found=true
        done < "$css_file"
    done < <(find "${theme_dir}/styles" -maxdepth 1 -type f -name '*.css' -print 2>/dev/null | sort)

    [[ "$found" == true ]] || echo "  No hexadecimal theme colors detected."
}

show_pandoc_palette() {
    local style="$1"
    local palette tmp label color seen="|"

    echo ""
    echo -e "${boldWhite}Pandoc palette: ${style}${endColour}"

    if ! command_exists pandoc; then
        echo "  Pandoc not installed."
        return 1
    fi

    palette=$(pandoc "--print-highlight-style=${style}" 2>/dev/null) || {
        echo "  Unable to read Pandoc highlight style '${style}'."
        return 1
    }

    # Show base foreground/background first.
    color=$(sed -nE 's/^[[:space:]]*"text-color":[[:space:]]*"(#[0-9A-Fa-f]{6})".*/\1/p' <<< "$palette" | head -1)
    [[ -n "$color" ]] && {
        print_color_swatch "foreground" "$color"
        seen+="${color}|"
    }

    color=$(sed -nE 's/^[[:space:]]*"background-color":[[:space:]]*"(#[0-9A-Fa-f]{6})".*/\1/p' <<< "$palette" | head -1)
    [[ -n "$color" ]] && {
        print_color_swatch "background" "$color"
        seen+="${color}|"
    }

    # Then expose the unique token colors in the exact style returned by Pandoc.
    local count=0
    while IFS= read -r color; do
        [[ "$seen" == *"|${color}|"* ]] && continue
        seen+="${color}|"
        ((count += 1))
        print_color_swatch "token-${count}" "$color"
        (( count >= 12 )) && break
    done < <(grep -Eo '#[0-9A-Fa-f]{6}' <<< "$palette")

    (( count > 0 )) || echo "  No token colors detected."
}

path_is_safe_relative() {
    local value="$1"
    [[ -n "$value" ]] || return 1
    [[ "$value" != /* ]] || return 1
    [[ "$value" != "." && "$value" != ".." ]] || return 1
    [[ "$value" != ../* && "$value" != */../* && "$value" != */.. ]] || return 1
}

site_public_is_stale() {
    local source_dir="$1"
    local output_dir="$2"
    local newest_source newest_output

    [[ -d "$output_dir" ]] || return 0

    newest_source=$(find "$source_dir" -type f \( -name '*.md' -o -name '*.markdown' \) -printf '%T@\n' 2>/dev/null | sort -nr | head -1)
    newest_output=$(find "$output_dir" -type f -name '*.html' -printf '%T@\n' 2>/dev/null | sort -nr | head -1)

    [[ -n "$newest_source" ]] || return 1
    [[ -n "$newest_output" ]] || return 0

    awk -v src="$newest_source" -v out="$newest_output" 'BEGIN { exit !(src > out) }'
}

diagnose_site() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 2

    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file

    print_section "Doctor: ${site_slug}"

    if [[ ! -d "$site_dir" ]]; then
        msg_error "Site directory does not exist: ${site_dir}"
        return 2
    fi

    if ! config_file=$(find_site_config "$site_dir"); then
        msg_error "Missing config.yaml/config.yml."
        return 2
    fi

    local errors=0 warnings=0
    local title desc author lang url theme highlight content_rel output_rel
    title=$(get_site_yaml_prop "$config_file" site title "")
    desc=$(get_site_yaml_prop "$config_file" site description "")
    author=$(get_site_yaml_prop "$config_file" site author "")
    lang=$(get_site_yaml_prop "$config_file" site language "")
    url=$(get_site_yaml_prop "$config_file" site url "")
    theme=$(get_site_yaml_prop "$config_file" theme name "")
    highlight=$(get_site_yaml_prop "$config_file" theme pandoc_theme "")
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir "")
    output_rel=$(get_site_yaml_prop "$config_file" build output_dir "")

    doctor_ok()   { printf '  %b %-20s %s\n' "${boldGreen}[OK]${endColour}" "$1" "$2"; }
    doctor_warn() { printf '  %b %-20s %s\n' "${boldYellow}[WARN]${endColour}" "$1" "$2"; ((warnings += 1)); }
    doctor_fail() { printf '  %b %-20s %s\n' "${boldRed}[FAIL]${endColour}" "$1" "$2"; ((errors += 1)); }

    echo -e "${boldWhite}Configuration${endColour}"

    [[ -n "$title" ]] && doctor_ok "site.title" "$title" || doctor_fail "site.title" "missing"
    [[ -n "$desc" ]] && doctor_ok "site.description" "$desc" || doctor_warn "site.description" "missing"
    [[ -n "$author" ]] && doctor_ok "site.author" "$author" || doctor_warn "site.author" "missing"

    if [[ "$lang" =~ ^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$ ]]; then
        doctor_ok "site.language" "$lang"
    else
        doctor_fail "site.language" "${lang:-missing} (expected e.g. en, es, es-ES)"
    fi

    if [[ "$url" =~ ^https?://[^[:space:]]+$ ]]; then
        if [[ "$url" == "https://example.com"* || "$url" == "http://example.com"* ]]; then
            doctor_warn "site.url" "$url (placeholder)"
        elif [[ "$url" == http://* ]]; then
            doctor_warn "site.url" "$url (HTTP; HTTPS recommended for deploy)"
        else
            doctor_ok "site.url" "$url"
        fi
    else
        doctor_fail "site.url" "${url:-missing} (absolute http/https URL required)"
    fi

    if theme_exists "$theme"; then
        doctor_ok "theme.name" "$theme"
    else
        doctor_fail "theme.name" "${theme:-missing} (theme not found)"
    fi

    if highlight_style_exists "$highlight"; then
        doctor_ok "pandoc_theme" "$highlight"
    else
        doctor_fail "pandoc_theme" "${highlight:-missing} (style not available)"
    fi

    if path_is_safe_relative "$content_rel"; then
        doctor_ok "content_dir" "$content_rel"
    else
        doctor_fail "content_dir" "${content_rel:-missing} (unsafe/invalid relative path)"
    fi

    if path_is_safe_relative "$output_rel"; then
        doctor_ok "output_dir" "$output_rel"
    else
        doctor_fail "output_dir" "${output_rel:-missing} (unsafe/invalid relative path)"
    fi

    echo ""
    echo -e "${boldWhite}Runtime and content${endColour}"

    if command_exists pandoc; then
        doctor_ok "Pandoc" "$(pandoc --version | head -1)"
    else
        doctor_fail "Pandoc" "not installed"
    fi

    if command_exists python3; then
        doctor_ok "Preview runtime" "$(python3 --version 2>&1)"
    else
        doctor_warn "Preview runtime" "python3 missing; build works but local preview is unavailable"
    fi

    local content_dir="${site_dir}/${content_rel:-posts}"
    local output_dir="${site_dir}/${output_rel:-public}"
    local post_count=0

    if [[ -d "$content_dir" ]]; then
        post_count=$(find "$content_dir" -type f \( -name '*.md' -o -name '*.markdown' \) | wc -l | tr -d ' ')
        if (( post_count > 0 )); then
            doctor_ok "Posts" "${post_count} Markdown file(s)"
        else
            doctor_warn "Posts" "no Markdown posts found"
        fi
    else
        doctor_fail "Posts" "content directory missing: ${content_dir}"
    fi

    local duplicate_output
    duplicate_output=$(
        if [[ -d "$content_dir" ]]; then
            find "$content_dir" -type f -name '*.md' -print0 |
            while IFS= read -r -d '' md_file; do
                declare -A doctor_meta=()
                get_post_metadata "$md_file" doctor_meta
                printf '%s/%s.html\n' "${doctor_meta["year"]}" "${doctor_meta["slug"]}"
            done | sort | uniq -d | head -1
        fi
    )
    if [[ -n "$duplicate_output" ]]; then
        doctor_fail "Post routes" "duplicate output path: posts/${duplicate_output}"
    else
        doctor_ok "Post routes" "no duplicate generated routes"
    fi

    echo ""
    echo -e "${boldWhite}Generated deploy artifact${endColour}"

    if [[ -d "$output_dir" ]]; then
        doctor_ok "public/" "$output_dir"

        [[ -s "${output_dir}/index.html" ]] && doctor_ok "index.html" "present" || doctor_fail "index.html" "missing"
        [[ -s "${output_dir}/posts.html" ]] && doctor_ok "posts.html" "present" || doctor_warn "posts.html" "missing"
        [[ -s "${output_dir}/robots.txt" ]] && doctor_ok "robots.txt" "present" || doctor_fail "robots.txt" "missing"
        [[ -s "${output_dir}/sitemap.xml" ]] && doctor_ok "sitemap.xml" "present" || doctor_fail "sitemap.xml" "missing"

        if find "$output_dir" -type f \( -name '*.md' -o -name '*.markdown' -o -name 'config.yaml' -o -name 'config.yml' \) | grep -q .; then
            doctor_fail "Artifact hygiene" "Markdown/config files leaked into public/"
        else
            doctor_ok "Artifact hygiene" "no Markdown/config files in public/"
        fi

        if site_public_is_stale "$content_dir" "$output_dir"; then
            doctor_warn "Freshness" "Markdown is newer than generated HTML; rebuild before deploy"
        else
            doctor_ok "Freshness" "generated HTML is current"
        fi

        if [[ -n "$url" && -s "${output_dir}/robots.txt" ]] &&
           grep -Fq "Sitemap: ${url%/}/sitemap.xml" "${output_dir}/robots.txt"; then
            doctor_ok "robots sitemap" "matches site.url"
        elif [[ -s "${output_dir}/robots.txt" ]]; then
            doctor_warn "robots sitemap" "does not match current site.url; rebuild recommended"
        fi

        if [[ -n "$url" && -s "${output_dir}/sitemap.xml" ]] &&
           grep -Fq "<loc>${url%/}/" "${output_dir}/sitemap.xml"; then
            doctor_ok "sitemap URLs" "use site.url"
        elif [[ -s "${output_dir}/sitemap.xml" ]]; then
            doctor_warn "sitemap URLs" "do not appear to use current site.url"
        fi
    else
        doctor_warn "public/" "not built yet"
    fi

    if theme_exists "$theme"; then
        show_theme_palette "$theme"
    fi
    if highlight_style_exists "$highlight"; then
        show_pandoc_palette "$highlight" || true
    fi

    echo ""
    print_separator
    if (( errors > 0 )); then
        msg_error "Doctor found ${errors} blocking issue(s) and ${warnings} warning(s)."
        return 1
    fi

    if (( warnings > 0 )); then
        msg_warn "Doctor found no blocking issues and ${warnings} warning(s)."
    else
        msg_success "Doctor: site is ready for deployment."
    fi
    return 0
}

create_new_site() {
    print_section "Create site"

    local site_title site_desc site_author site_lang site_url site_slug
    read -rp "Title [My New Blog]: " site_title
    site_title="${site_title:-My New Blog}"
    read -rp "Description [A static blog built with Zeta]: " site_desc
    site_desc="${site_desc:-A static blog built with Zeta}"
    read -rp "Author [${USER:-Author}]: " site_author
    site_author="${site_author:-${USER:-Author}}"
    read -rp "Language [en]: " site_lang
    site_lang="${site_lang:-en}"

    local default_slug
    default_slug=$(slugify "$site_title")
    read -rp "Site slug [${default_slug}]: " site_slug
    site_slug="${site_slug:-$default_slug}"

    if ! is_valid_site_slug "$site_slug"; then
        msg_error "Site slug must be a safe directory name (no path separators or control characters)."
        return 1
    fi

    local site_path="${SITES_DIR}/${site_slug}"
    if [[ -e "$site_path" ]]; then
        msg_error "'${site_path}' already exists."
        return 1
    fi

    read -rp "Production URL for sitemap [https://example.com]: " site_url
    site_url="${site_url:-https://example.com}"
    site_url="${site_url%/}"

    local selected_theme selected_pandoc_theme
    selected_theme=$(choose_theme_interactive "zen")
    selected_pandoc_theme=$(choose_highlight_interactive "zenburn")

    mkdir -p "${site_path}/posts"
    write_site_config "${site_path}/config.yaml" \
        "$site_title" "$site_desc" "$site_author" "$site_lang" "$site_url" \
        "$selected_theme" "$selected_pandoc_theme" "posts" "public"

    create_example_posts "$site_slug" || return 1

    msg_success "Site '${site_slug}' created."
    msg_info "Markdown source: ${site_path}/posts/"
    msg_info "Two example posts were created to validate Markdown and syntax highlighting."
    msg_info "Build output: ${site_path}/public/"
    update_sites_index
}

edit_site() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Site '${site_slug}' has no config file."
        return 1
    }

    print_section "Edit site: ${site_slug}"

    local title desc author lang url theme highlight content_rel output_rel value
    title=$(get_site_yaml_prop "$config_file" site title "$site_slug")
    desc=$(get_site_yaml_prop "$config_file" site description "")
    author=$(get_site_yaml_prop "$config_file" site author "${USER:-Author}")
    lang=$(get_site_yaml_prop "$config_file" site language "en")
    url=$(get_site_yaml_prop "$config_file" site url "https://example.com")
    theme=$(get_site_yaml_prop "$config_file" theme name "zen")
    highlight=$(get_site_yaml_prop "$config_file" theme pandoc_theme "zenburn")
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir "posts")
    output_rel=$(get_site_yaml_prop "$config_file" build output_dir "public")

    read -rp "Title [${title}]: " value; title="${value:-$title}"
    read -rp "Description [${desc}]: " value; desc="${value:-$desc}"
    read -rp "Author [${author}]: " value; author="${value:-$author}"
    read -rp "Language [${lang}]: " value; lang="${value:-$lang}"
    read -rp "Production URL [${url}]: " value; url="${value:-$url}"; url="${url%/}"

    theme=$(choose_theme_interactive "$theme")
    highlight=$(choose_highlight_interactive "$highlight")

    write_site_config "$config_file" "$title" "$desc" "$author" "$lang" "$url" \
        "$theme" "$highlight" "$content_rel" "$output_rel"

    msg_success "Configuration updated for '${site_slug}'."
    msg_info "Run './main.sh build ${site_slug}' to regenerate public/."
    update_sites_index
}

clean_site() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    local content_rel output_rel
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir posts)
    output_rel=$(get_site_yaml_prop "$config_file" build output_dir public)
    is_safe_relative_dir "$content_rel" || {
        msg_error "Unsafe content directory in config: '${content_rel}'."
        return 1
    }
    is_safe_relative_dir "$output_rel" || {
        msg_error "Unsafe output directory in config: '${output_rel}'."
        return 1
    }
    content_rel="${content_rel%/}"
    output_rel="${output_rel%/}"
    if build_dirs_overlap "$content_rel" "$output_rel"; then
        msg_error "Refusing to clean because content and output directories overlap."
        return 1
    fi

    local output_path previous_path
    output_path="${site_dir:?}/${output_rel:?}"
    previous_path="${output_path}.zeta-previous"

    rm -rf -- "$output_path" "$previous_path"
    rm -rf -- "${site_dir:?}"/.zeta-build-*
    msg_success "Removed generated output for '${site_slug}'. Source Markdown was preserved."
    update_sites_index
}

delete_site() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1
    local site_dir="${SITES_DIR}/${site_slug}"

    [[ -d "$site_dir" && ! -L "$site_dir" ]] || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    if [[ "$FORCE" != true ]]; then
        echo "This permanently deletes config, posts, assets and generated public files for '${site_slug}'."
        local confirmation
        read -rp "Type '${site_slug}' to confirm: " confirmation
        if [[ "$confirmation" != "$site_slug" ]]; then
            msg_info "Deletion cancelled."
            return 0
        fi
    fi

    rm -rf -- "$site_dir"
    msg_success "Site '${site_slug}' deleted from the local workspace."
    update_sites_index
}

list_posts() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    local content_rel content_dir site_author
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir posts)
    site_author=$(get_site_yaml_prop "$config_file" site author "")
    is_safe_relative_dir "$content_rel" || return 1
    content_dir="${site_dir}/${content_rel}"

    printf '\nPosts for %s\n\n' "$site_slug"
    if [[ ! -d "$content_dir" ]]; then
        msg_info "No content directory yet."
        return 0
    fi

    local files=()
    readarray -t files < <(find "$content_dir" -type f -name '*.md' -print | sort -r)
    if [[ ${#files[@]} -eq 0 ]]; then
        msg_info "No Markdown posts found in ${content_rel}/."
        return 0
    fi

    printf '%-12s %-42s %s\n' "DATE" "TITLE" "FILE"
    printf '%-12s %-42s %s\n' "----------" "------------------------------------------" "------------------------------"
    local file
    for file in "${files[@]}"; do
        declare -A post=()
        get_post_metadata "$file" post "$site_author"
        printf '%-12s %-42.42s %s\n' "${post[date]}" "${post[title]}" "${file#"${site_dir}/"}"
    done
    echo ""
}

create_post() {
    local site_slug="$1"
    require_site_slug "$site_slug" || return 1
    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Unknown site: '${site_slug}'."
        return 1
    }

    local content_rel content_dir site_author title slug description tags post_date file
    content_rel=$(get_site_yaml_prop "$config_file" build content_dir posts)
    site_author=$(get_site_yaml_prop "$config_file" site author "${USER:-Author}")
    is_safe_relative_dir "$content_rel" || return 1
    content_dir="${site_dir}/${content_rel}"
    mkdir -p "$content_dir"

    print_section "Create post: ${site_slug}"
    read -rp "Post title: " title
    [[ -n "$title" ]] || { msg_error "Post title cannot be empty."; return 1; }

    local default_slug
    default_slug=$(slugify "$title")
    read -rp "Slug [${default_slug}]: " slug
    slug="${slug:-$default_slug}"
    slug=$(slugify "$slug")
    read -rp "Description [${title}]: " description
    description="${description:-$title}"
    read -rp "Tags, comma-separated [none]: " tags
    post_date=$(date +%Y-%m-%d)
    file="${content_dir}/${post_date}-${slug}.md"

    if [[ -e "$file" && "$FORCE" != true ]]; then
        msg_error "Post already exists: ${file}"
        return 1
    fi

    cat > "$file" <<EOF_POST
---
title: $(yaml_quote "$title")
author: $(yaml_quote "$site_author")
date: $(yaml_quote "$post_date")
description: $(yaml_quote "$description")
slug: $(yaml_quote "$slug")
EOF_POST

    if [[ -n "$(trim_yaml_value "$tags")" ]]; then
        echo "tags:" >> "$file"
        local -a tag_items=()
        local tag
        IFS=',' read -r -a tag_items <<< "$tags"
        for tag in "${tag_items[@]}"; do
            tag=$(trim_yaml_value "$tag")
            [[ -n "$tag" ]] && printf '  - %s\n' "$(yaml_quote "$tag")" >> "$file"
        done
    else
        echo "tags: []" >> "$file"
    fi

    cat >> "$file" <<EOF_POST
---

Write your introduction here.

## First section

Continue your post here.
EOF_POST

    msg_success "Created ${file#"${site_dir}/"}"

    if [[ -n "${EDITOR:-}" && -t 0 && -t 1 ]]; then
        local answer
        read -rp "Open it with ${EDITOR}? [Y/n]: " answer
        if [[ ! "${answer:-Y}" =~ ^[Nn]$ ]]; then
            "$EDITOR" "$file"
        fi
    fi
}

build_all_sites() {
    print_section "Build all sites"
    local sites=()
    readarray -t sites < <(get_all_sites)

    if [[ ${#sites[@]} -eq 0 ]]; then
        msg_warn "No sites found in workspace."
        return 0
    fi

    local site_slug
    for site_slug in "${sites[@]}"; do
        build_site "$site_slug" || return 1
    done
    update_sites_index
}

update_sites_index() {
    mkdir -p "$SITES_DIR"
    local index_file="${SITES_DIR}/index.html"
    local sites=()
    readarray -t sites < <(get_all_sites)

    {
        cat <<'EOF_HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Zeta local workspace</title>
  <style>
    :root{color-scheme:dark;--bg:#0d1117;--panel:#161b22;--border:#30363d;--text:#e6edf3;--muted:#8b949e;--accent:#58a6ff}
    *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    main{max-width:72rem;margin:auto;padding:2rem 1rem}h1{margin:0 0 .35rem}.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(16rem,1fr));gap:1rem;margin-top:2rem}
    a.card{display:block;padding:1.1rem;border:1px solid var(--border);border-radius:.6rem;background:var(--panel);color:inherit;text-decoration:none}a.card:hover,a.card:focus{border-color:var(--accent);outline:none}.card strong{display:block;margin-bottom:.35rem}.meta{font-size:.875rem;color:var(--muted)}
  </style>
</head>
<body>
<main>
  <h1>Zeta local workspace</h1>
  <p class="muted">Generated sites. Only each site's public/ directory is deployable.</p>
  <div class="grid">
EOF_HTML

        local site
        for site in "${sites[@]}"; do
            local site_dir="${SITES_DIR}/${site}"
            local config_file title description output_rel
            config_file=$(find_site_config "$site_dir")
            title=$(get_site_yaml_prop "$config_file" site title "$site")
            description=$(get_site_yaml_prop "$config_file" site description "")
            title=$(html_escape "$title")
            description=$(html_escape "$description")
            output_rel=$(get_site_yaml_prop "$config_file" build output_dir public)
            if [[ -f "${site_dir}/${output_rel}/index.html" ]]; then
                printf '    <a class="card" href="./%s/%s/"><strong>%s</strong><span class="meta">%s post(s)</span><br><span class="meta">%s</span></a>\n' \
                    "$site" "$output_rel" "$title" "$(site_post_count "$site")" "$description"
            else
                printf '    <div class="card"><strong>%s</strong><span class="meta">Not built yet</span><br><span class="meta">%s</span></div>\n' "$title" "$description"
            fi
        done

        cat <<'EOF_HTML'
  </div>
</main>
</body>
</html>
EOF_HTML
    } > "$index_file"
}

run_static_server() {
    local directory="$1"
    local port="$2"
    local python_cmd=""

    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        msg_error "Invalid preview port: '${port}'."
        return 2
    fi

    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python && python -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' 2>/dev/null; then
        python_cmd="python"
    else
        msg_error "Local preview requires Python 3. Build output is ready; serve '${directory}' with any static HTTP server."
        return 1
    fi

    msg_info "Serving ${directory} at http://127.0.0.1:${port}/"
    msg_info "Press Ctrl+C to stop the preview."

    set +e
    "$python_cmd" -m http.server "$port" --bind 127.0.0.1 --directory "$directory"
    local rc=$?
    set -e

    [[ $rc -eq 130 ]] && return 0
    return "$rc"
}

preview_site() {
    local site_slug="$1"
    local port="${2:-$PREVIEW_PORT}"
    build_site "$site_slug" || return 1

    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file output_rel
    config_file=$(find_site_config "$site_dir")
    output_rel=$(get_site_yaml_prop "$config_file" build output_dir public)
    run_static_server "${site_dir}/${output_rel}" "$port"
}

serve_workspace() {
    local port="${1:-$PREVIEW_PORT}"
    build_all_sites || return 1
    update_sites_index
    run_static_server "$SITES_DIR" "$port"
}
