# shellcheck disable=SC1091,SC2034,SC2155

find_site_config() {
    local site_dir="$1"

    if [[ -f "${site_dir}/config.yaml" ]]; then
        printf '%s\n' "${site_dir}/config.yaml"
    elif [[ -f "${site_dir}/config.yml" ]]; then
        printf '%s\n' "${site_dir}/config.yml"
    else
        return 1
    fi
}

is_safe_relative_dir() {
    local value="$1"
    [[ -n "$value" ]] || return 1
    [[ "$value" != /* ]] || return 1
    [[ "$value" != "." && "$value" != ".." ]] || return 1
    [[ "$value" != ../* && "$value" != */../* && "$value" != */.. ]] || return 1
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || return 1
}

is_valid_site_slug() {
    local value="${1:-}"

    [[ -n "$value" ]] || return 1
    [[ "$value" != "." && "$value" != ".." ]] || return 1

    # A site slug is a single directory name, never a path.
    [[ "$value" != */* && "$value" != *\\* ]] || return 1

    # Bash strings cannot contain NUL bytes, so checking $'\\0' here is both
    # unnecessary and incorrect. Reject control characters Bash can receive.
    [[ "$value" != *$'\n'* ]] || return 1
    [[ "$value" != *$'\r'* ]] || return 1
    [[ "$value" != *$'\t'* ]] || return 1

    return 0
}

build_dirs_overlap() {
    local content="$1"
    local output="$2"
    content="${content%/}"
    output="${output%/}"
    [[ "$content" == "$output" || "$content" == "$output/"* || "$output" == "$content/"* ]]
}

html_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\\&#39;/g"
}

xml_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g'
}

get_site_yaml_prop() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default_val="${4:-}"

    [[ -f "$file" ]] || { echo "$default_val"; return 0; }

    local val
    val=$(awk -v sec="${section}:" -v k="${key}:" '
        $0 ~ "^" sec "[[:space:]]*$" { in_sec=1; next }
        in_sec && /^[^ \t]/ { in_sec=0 }
        in_sec && $1 == k {
            $1=""
            sub(/^[[:space:]]+/, "")
            print
            exit
        }
    ' "$file" 2>/dev/null)

    if [[ -n "$val" ]]; then
        decode_yaml_scalar "$val"
        printf '\n'
    else
        echo "$default_val"
    fi
}

get_post_metadata() {
    local md_file="$1"
    declare -n meta="$2"
    local site_author_fallback="${3:-}"

    meta=()

    local raw_filename
    local post_title post_author post_date post_human_date
    local post_description post_year post_slug post_tags

    raw_filename=$(basename "$md_file" .md)
    post_title=$(extract_frontmatter_property "$md_file" "title" 2>/dev/null || true)
    post_author=$(extract_frontmatter_property "$md_file" "author" 2>/dev/null || true)
    post_date=$(extract_frontmatter_property "$md_file" "date" 2>/dev/null || true)
    post_human_date=$(extract_frontmatter_property "$md_file" "human_date" 2>/dev/null || true)
    post_description=$(extract_frontmatter_property "$md_file" "description" 2>/dev/null || true)
    post_year=$(extract_frontmatter_property "$md_file" "year" 2>/dev/null || true)
    post_slug=$(extract_frontmatter_property "$md_file" "slug" 2>/dev/null || true)
    post_tags=$(extract_frontmatter_tags "$md_file" 2>/dev/null || true)

    meta["raw_filename"]="$raw_filename"
    meta["title"]="$post_title"
    meta["author"]="$post_author"
    meta["date"]="$post_date"
    meta["human_date"]="$post_human_date"
    meta["description"]="$post_description"
    meta["year"]="$post_year"
    meta["slug"]="$post_slug"
    meta["tags"]="$post_tags"

    if [[ -z "${meta["slug"]}" ]]; then
        if [[ "$raw_filename" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.*)$ ]]; then
            meta["slug"]="${BASH_REMATCH[1]}"
        elif [[ "$raw_filename" =~ ^[0-9]{4}-(.*)$ ]]; then
            meta["slug"]="${BASH_REMATCH[1]}"
        else
            meta["slug"]="$raw_filename"
        fi
    fi

    meta["slug"]=$(slugify "${meta["slug"]}")
    [[ -n "${meta["slug"]}" ]] || meta["slug"]="post"

    if [[ -z "${meta["date"]}" ]]; then
        if [[ "$raw_filename" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})- ]]; then
            meta["date"]="${BASH_REMATCH[1]}"
        else
            meta["date"]="$(date +%Y-%m-%d)"
        fi
    fi

    if [[ ! "${meta["year"]}" =~ ^[0-9]{4}$ ]]; then
        if [[ "${meta["date"]}" =~ ^([0-9]{4}) ]]; then
            meta["year"]="${BASH_REMATCH[1]}"
        else
            meta["year"]="$(date +%Y)"
        fi
    fi

    meta["title"]="${meta["title"]:-${meta["slug"]}}"
    meta["author"]="${meta["author"]:-$site_author_fallback}"
    meta["human_date"]="${meta["human_date"]:-${meta["date"]}}"
    meta["description"]="${meta["description"]:-${meta["title"]}}"
}

copy_tree_contents() {
    local source_dir="$1"
    local target_dir="$2"

    [[ -d "$source_dir" ]] || return 0
    mkdir -p "$target_dir"
    cp -a "${source_dir}/." "$target_dir/"
}

append_css_vars() {
    declare -n options_ref="$1"
    local prefix="$2"
    local theme_styles="$3"
    local site_styles="${4:-}"
    local css_file

    # Common baseline order matters: normalize first, then semantic Markdown.
    if [[ -f "${TEMPLATES_DIR}/common/styles/normalize.css" ]]; then
        options_ref+=(-V "css=${prefix}styles/normalize.css")
    fi

    if [[ -d "${TEMPLATES_DIR}/common/styles" ]]; then
        while IFS= read -r css_file; do
            [[ -f "$css_file" ]] || continue
            [[ "$(basename "$css_file")" == "normalize.css" ]] && continue
            options_ref+=(-V "css=${prefix}styles/$(basename "$css_file")")
        done < <(find "${TEMPLATES_DIR}/common/styles" -maxdepth 1 -type f -name '*.css' -print | sort)
    fi

    # Theme presentation follows the shared semantic baseline.
    if [[ -d "$theme_styles" ]]; then
        while IFS= read -r css_file; do
            [[ -f "$css_file" ]] || continue
            options_ref+=(-V "css=${prefix}styles/$(basename "$css_file")")
        done < <(find "$theme_styles" -maxdepth 1 -type f -name '*.css' -print | sort)
    fi

    # Per-site customizations (including selected fonts) have final precedence.
    if [[ -n "$site_styles" && -d "$site_styles" ]]; then
        while IFS= read -r css_file; do
            [[ -f "$css_file" ]] || continue
            options_ref+=(-V "css=${prefix}styles/$(basename "$css_file")")
        done < <(find "$site_styles" -maxdepth 1 -type f -name '*.css' -print | sort)
    fi
}

normalize_site_url() {
    local url="$1"
    url="${url%/}"
    printf '%s\n' "$url"
}

write_robots_txt() {
    local output_dir="$1"
    local site_url="$2"
    local template="${TEMPLATES_DIR}/robots.txt"
    local target="${output_dir}/robots.txt"

    if [[ ! -f "$template" ]]; then
        msg_error "Missing robots.txt base template: ${template}"
        return 1
    fi

    local replacement="$site_url"
    replacement="${replacement//\\/\\\\}"
    replacement="${replacement//&/\\&}"
    replacement="${replacement//|/\\|}"

    sed "s|{{BASE_URL}}|${replacement}|g" "$template" > "$target"
}

generate_sitemap() {
    local content_dir="$1"
    local output_dir="$2"
    local site_url="$3"
    local site_author="$4"
    local sitemap_file="${output_dir}/sitemap.xml"
    local theme_xsl="$5"
    local today xml_site_url
    today=$(date +%Y-%m-%d)
    xml_site_url=$(xml_escape "$site_url")

    if [[ -f "$theme_xsl" ]]; then
        cp "$theme_xsl" "${output_dir}/sitemap.xsl"
    elif [[ -f "${TEMPLATES_DIR}/common/sitemap.xsl" ]]; then
        cp "${TEMPLATES_DIR}/common/sitemap.xsl" "${output_dir}/sitemap.xsl"
    fi

    cat > "$sitemap_file" <<EOF_XML
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="sitemap.xsl"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${xml_site_url}/</loc>
    <lastmod>${today}</lastmod>
    <priority>1.00</priority>
  </url>
EOF_XML

    if [[ -f "${output_dir}/posts.html" ]]; then
        cat >> "$sitemap_file" <<EOF_XML
  <url>
    <loc>${xml_site_url}/posts.html</loc>
    <lastmod>${today}</lastmod>
    <priority>0.90</priority>
  </url>
EOF_XML
    fi

    if [[ -d "$content_dir" ]]; then
        local md_file
        while IFS= read -r md_file; do
            declare -A post=()
            get_post_metadata "$md_file" post "$site_author"
            local lastmod="${post[date]}"
            [[ "$lastmod" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || lastmod="$today"
            cat >> "$sitemap_file" <<EOF_XML
  <url>
    <loc>${xml_site_url}/posts/${post[year]}/${post[slug]}.html</loc>
    <lastmod>${lastmod}</lastmod>
    <priority>0.80</priority>
  </url>
EOF_XML
        done < <(find "$content_dir" -type f -name '*.md' -print | sort)
    fi

    echo "</urlset>" >> "$sitemap_file"
}

build_site() {
    local site_slug="${1:-}"

    if [[ -z "$site_slug" ]]; then
        msg_error "No site slug provided."
        return 1
    fi
    if ! is_valid_site_slug "$site_slug"; then
        msg_error "Invalid site slug: '${site_slug}'."
        return 1
    fi

    local site_dir="${SITES_DIR}/${site_slug}"
    [[ -d "$site_dir" && ! -L "$site_dir" ]] || {
        msg_error "Site '${site_slug}' does not exist or is not a regular site directory."
        return 1
    }

    local config_file
    config_file=$(find_site_config "$site_dir") || {
        msg_error "Missing config.yaml/config.yml in '${site_dir}'."
        return 1
    }

    ensure_pandoc_installed || return 1

    local site_title site_desc site_author site_lang site_url site_theme pandoc_theme
    local content_rel output_rel
    site_title=$(get_site_yaml_prop "$config_file" "site" "title" "$site_slug")
    site_desc=$(get_site_yaml_prop "$config_file" "site" "description" "Static site generated with Zeta")
    site_author=$(get_site_yaml_prop "$config_file" "site" "author" "Author")
    site_lang=$(get_site_yaml_prop "$config_file" "site" "language" "en")
    site_url=$(normalize_site_url "$(get_site_yaml_prop "$config_file" "site" "url" "https://example.com")")
    site_theme=$(get_site_yaml_prop "$config_file" "theme" "name" "zen")
    pandoc_theme=$(get_site_yaml_prop "$config_file" "theme" "pandoc_theme" "zenburn")
    content_rel=$(get_site_yaml_prop "$config_file" "build" "content_dir" "posts")
    output_rel=$(get_site_yaml_prop "$config_file" "build" "output_dir" "public")

    if [[ ! "$site_url" =~ ^https?://[^[:space:]?#]+$ ]]; then
        msg_error "site.url must be an absolute http(s) URL without a query string or fragment."
        return 1
    fi
    if ! is_valid_site_slug "$site_theme"; then
        msg_error "Invalid theme name: '${site_theme}'."
        return 1
    fi

    is_safe_relative_dir "$content_rel" || {
        msg_error "Unsafe build.content_dir value: '${content_rel}'."
        return 1
    }
    is_safe_relative_dir "$output_rel" || {
        msg_error "Unsafe build.output_dir value: '${output_rel}'."
        return 1
    }

    content_rel="${content_rel%/}"
    output_rel="${output_rel%/}"
    if build_dirs_overlap "$content_rel" "$output_rel"; then
        msg_error "build.content_dir ('${content_rel}') and build.output_dir ('${output_rel}') must not overlap."
        return 1
    fi

    if [[ ! "$site_lang" =~ ^[A-Za-z][A-Za-z0-9-]*$ ]]; then
        msg_warn "Invalid site.language '${site_lang}'. Falling back to 'en' for generated HTML."
        site_lang="en"
    fi

    local html_site_title html_site_desc html_site_author html_site_lang
    html_site_title=$(html_escape "$site_title")
    html_site_desc=$(html_escape "$site_desc")
    html_site_author=$(html_escape "$site_author")
    html_site_lang=$(html_escape "$site_lang")

    local content_dir="${site_dir}/${content_rel}"
    local final_output_dir="${site_dir}/${output_rel}"
    local staging_dir="${site_dir}/.zeta-build-${BASHPID:-$$}"
    local output_dir="$staging_dir"
    local theme_dir="${TEMPLATES_DIR}/${site_theme}"

    [[ -d "$theme_dir" ]] || {
        msg_error "Theme '${site_theme}' was not found at '${theme_dir}'."
        return 1
    }
    [[ -f "${theme_dir}/article.html" && -f "${theme_dir}/post_link.html" ]] || {
        msg_error "Theme '${site_theme}' is missing article.html or post_link.html."
        return 1
    }

    if [[ "$site_url" == "https://example.com" ]]; then
        msg_warn "site.url still uses https://example.com. Update it before production deployment so robots.txt and sitemap.xml are correct."
    fi

    print_section "Build: ${site_slug}"
    msg_info "Source: ${content_rel}/"
    msg_info "Output: ${output_rel}/"
    msg_info "Theme: ${site_theme} | Pandoc highlight: ${pandoc_theme}"

    rm -rf -- "$staging_dir"
    mkdir -p "${output_dir}/posts" "${output_dir}/styles"

    # Every theme inherits templates/common first.
    copy_tree_contents "${TEMPLATES_DIR}/common/styles" "${output_dir}/styles"
    copy_tree_contents "${TEMPLATES_DIR}/common/assets" "${output_dir}/assets"

    # Theme resources override common resources with the same path.
    copy_tree_contents "${theme_dir}/styles" "${output_dir}/styles"
    copy_tree_contents "${theme_dir}/assets" "${output_dir}/assets"

    # Per-site resources are applied last and therefore have final precedence.
    copy_tree_contents "${site_dir}/styles" "${output_dir}/styles"
    copy_tree_contents "${site_dir}/assets" "${output_dir}/assets"

    local md_files=()
    if [[ -d "$content_dir" ]]; then
        readarray -t md_files < <(find "$content_dir" -type f -name '*.md' -print | sort -r)
    fi

    local posts_list_html=""
    local md_file
    local built_count=0
    declare -A generated_paths=()

    for md_file in "${md_files[@]}"; do
        declare -A post=()
        get_post_metadata "$md_file" post "$site_author"

        local html_post_title html_post_author html_post_date html_post_iso_date html_post_desc
        html_post_title=$(html_escape "${post[title]}")
        html_post_author=$(html_escape "${post[author]}")
        html_post_date=$(html_escape "${post[human_date]}")
        html_post_iso_date=$(html_escape "${post[date]}")
        html_post_desc=$(html_escape "${post[description]}")

        local rel_path="posts/${post[year]}/${post[slug]}.html"
        if [[ -n "${generated_paths[$rel_path]+x}" ]]; then
            msg_error "Duplicate generated path '${rel_path}' from '$(basename "$md_file")' and '$(basename "${generated_paths[$rel_path]}")'."
            rm -rf -- "$staging_dir"
            return 1
        fi
        generated_paths[$rel_path]="$md_file"

        local output_file="${output_dir}/${rel_path}"
        local rel_root="../../"
        mkdir -p "$(dirname "$output_file")"

        msg_build "$(basename "$md_file") -> ${rel_path}"

        local markdown_reader
        markdown_reader=$(pandoc_markdown_reader)

        local pandoc_opts=(
            "--from=${markdown_reader}"
            --to=html5
            --standalone
            --section-divs
            --wrap=none
            --table-of-contents
            --toc-depth=3
            --preserve-tabs
            --template="${theme_dir}/article.html"
            -V "rel_root=${rel_root}"
            -V "title=${html_post_title}"
            -V "author=${html_post_author}"
            -V "date=${html_post_date}"
            -V "iso_date=${html_post_iso_date}"
            -V "year=${post[year]}"
            -V "slug=${post[slug]}"
            -V "description=${html_post_desc}"
            -V "site_title=${html_site_title}"
            -V "site_author=${html_site_author}"
            -V "site_lang=${html_site_lang}"
        )

        local highlight_flag=""
        highlight_flag=$(pandoc_highlight_option 2>/dev/null || true)
        if [[ -n "$highlight_flag" ]]; then
            pandoc_opts+=("${highlight_flag}=${pandoc_theme}")
        else
            msg_warn "This Pandoc build exposes no configurable syntax-highlighting flag; using its default highlighting."
        fi

        local table_filter="${TEMPLATES_DIR}/common/filters/table-wrapper.lua"
        if [[ -f "$table_filter" ]]; then
            pandoc_opts+=(--lua-filter="$table_filter")
        fi

        append_css_vars pandoc_opts "$rel_root" "${theme_dir}/styles" "${site_dir}/styles"

        if [[ -n "${post[tags]}" ]]; then
            local -a tag_items=()
            local tag
            IFS=',' read -r -a tag_items <<< "${post[tags]}"
            for tag in "${tag_items[@]}"; do
                tag=$(trim_yaml_value "$tag")
                [[ -n "$tag" ]] && pandoc_opts+=(-V "tags=$(html_escape "$tag")")
            done
        fi

        if ! pandoc "$md_file" "${pandoc_opts[@]}" -o "$output_file"; then
            msg_error "Pandoc failed while compiling: ${md_file}"
            rm -rf -- "$staging_dir"
            return 1
        fi

        local item_html
        if ! item_html=$(pandoc /dev/null --quiet \
            --template="${theme_dir}/post_link.html" \
            -V "title=${html_post_title}" \
            -V "date=${html_post_date}" \
            -V "iso_date=${html_post_iso_date}" \
            -V "path=${rel_path}"); then
            msg_error "Pandoc failed while rendering the post list item for: ${md_file}"
            rm -rf -- "$staging_dir"
            return 1
        fi
        posts_list_html+="${item_html}"$'\n'
        ((built_count++)) || true
    done

    local html_file
    while IFS= read -r html_file; do
        local base_html
        base_html=$(basename "$html_file")
        case "$base_html" in
            article.html|post_link.html) continue ;;
        esac

        local page_opts=(
            --from=markdown
            --to=html5
            --quiet
            --template="$html_file"
            -V "site_lang=${html_site_lang}"
            -V "site_title=${html_site_title}"
            -V "site_desc=${html_site_desc}"
            -V "site_author=${html_site_author}"
            -V "posts_list=${posts_list_html}"
        )
        append_css_vars page_opts "" "${theme_dir}/styles" "${site_dir}/styles"
        if ! pandoc /dev/null "${page_opts[@]}" -o "${output_dir}/${base_html}"; then
            msg_error "Pandoc failed while rendering page template: ${base_html}"
            rm -rf -- "$staging_dir"
            return 1
        fi
    done < <(find "$theme_dir" -maxdepth 1 -type f -name '*.html' -print | sort)

    [[ -f "${output_dir}/index.html" ]] || {
        msg_error "Theme '${site_theme}' did not generate index.html."
        rm -rf -- "$staging_dir"
        return 1
    }

    if ! write_robots_txt "$output_dir" "$site_url" || \
       ! generate_sitemap "$content_dir" "$output_dir" "$site_url" "$site_author" "${theme_dir}/sitemap.xsl"; then
        msg_error "Failed to generate robots.txt or sitemap.xml."
        rm -rf -- "$staging_dir"
        return 1
    fi

    local previous_output="${final_output_dir}.zeta-previous"
    mkdir -p "$(dirname "$final_output_dir")"
    rm -rf -- "$previous_output"
    if [[ -e "$final_output_dir" ]]; then
        mv -- "$final_output_dir" "$previous_output" || {
            msg_error "Could not stage the previous build for replacement."
            rm -rf -- "$staging_dir"
            return 1
        }
    fi

    if ! mv -- "$staging_dir" "$final_output_dir"; then
        msg_error "Could not publish the completed build to '${final_output_dir}'."
        [[ -e "$previous_output" ]] && mv -- "$previous_output" "$final_output_dir" 2>/dev/null || true
        rm -rf -- "$staging_dir"
        return 1
    fi
    rm -rf -- "$previous_output"

    msg_success "Site '${site_slug}' built: ${built_count} post(s) -> ${final_output_dir}"
}
