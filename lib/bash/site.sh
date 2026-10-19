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
    local post_description post_year post_slug post_tags post_external_url

    raw_filename=$(basename "$md_file" .md)
    post_title=$(extract_frontmatter_property "$md_file" "title" 2>/dev/null || true)
    post_author=$(extract_frontmatter_property "$md_file" "author" 2>/dev/null || true)
    post_date=$(extract_frontmatter_property "$md_file" "date" 2>/dev/null || true)
    post_human_date=$(extract_frontmatter_property "$md_file" "human_date" 2>/dev/null || true)
    post_description=$(extract_frontmatter_property "$md_file" "description" 2>/dev/null || true)
    post_external_url=$(extract_frontmatter_property "$md_file" "external_url" 2>/dev/null || true)
    post_year=$(extract_frontmatter_property "$md_file" "year" 2>/dev/null || true)
    post_slug=$(extract_frontmatter_property "$md_file" "slug" 2>/dev/null || true)
    post_tags=$(extract_frontmatter_tags "$md_file" 2>/dev/null || true)

    meta["raw_filename"]="$raw_filename"
    meta["title"]="$post_title"
    meta["author"]="$post_author"
    meta["date"]="$post_date"
    meta["human_date"]="$post_human_date"
    meta["description"]="$post_description"
    meta["external_url"]="$post_external_url"
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

# Only HTTP(S), relative links and anchors may be written to href attributes.
is_safe_public_link() {
    local link="$1"
    local absolute_pattern='^https?://[^[:space:]"<>]+$'
    local relative_pattern='^[A-Za-z0-9][A-Za-z0-9_./?&=%#+~-]*$'
    [[ -n "$link" ]] || return 1
    case "$link" in
        https://*|http://*) [[ "$link" =~ $absolute_pattern ]] ;;
        \#*) [[ "$link" =~ ^\#[A-Za-z0-9_-]+$ ]] ;;
        *)
            [[ "$link" =~ $relative_pattern ]] &&
            [[ "$link" != ../* && "$link" != */../* && "$link" != */.. && "$link" != //* ]]
            ;;
    esac
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

    # Separate optional landing settings survive config.yaml changes.
    local landing_file="${site_dir}/landing.yaml"
    local landing_eyebrow landing_primary_label landing_primary_url landing_secondary_label landing_secondary_url
    local landing_hero_image landing_hero_alt
    landing_eyebrow=$(get_site_yaml_prop "$landing_file" landing eyebrow "")
    landing_primary_label=$(get_site_yaml_prop "$landing_file" landing primary_label "")
    landing_primary_url=$(get_site_yaml_prop "$landing_file" landing primary_url "")
    landing_secondary_label=$(get_site_yaml_prop "$landing_file" landing secondary_label "")
    landing_secondary_url=$(get_site_yaml_prop "$landing_file" landing secondary_url "")
    landing_hero_image=$(get_site_yaml_prop "$landing_file" landing hero_image "")
    landing_hero_alt=$(get_site_yaml_prop "$landing_file" landing hero_alt "")
    local landing_link
    for landing_link in "$landing_primary_url" "$landing_secondary_url"; do
        if [[ -n "$landing_link" ]] && ! is_safe_public_link "$landing_link"; then
            msg_error "Invalid landing URL: ${landing_link}"
            return 1
        fi
    done
    if [[ -n "$landing_hero_image" ]]; then
        if [[ ! "$landing_hero_image" =~ ^assets/[A-Za-z0-9_./-]+$ ||
              "$landing_hero_image" == *../* || "$landing_hero_image" == */.. ]]; then
            msg_error "landing.hero_image must use a relative assets/ path without traversal."
            return 1
        fi
        if [[ ! -f "${site_dir}/${landing_hero_image}" ]]; then
            msg_error "Missing landing hero image: ${site_dir}/${landing_hero_image}"
            return 1
        fi
    fi

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

    local landing_content=""
    if [[ -f "${site_dir}/landing.md" ]]; then
        local landing_reader
        landing_reader=$(pandoc_markdown_reader)
        if ! landing_content=$(pandoc "${site_dir}/landing.md" "--from=${landing_reader}" --to=html5 --wrap=none); then
            msg_error "Could not render landing.md for site ${site_slug}."
            rm -rf -- "$staging_dir"
            return 1
        fi
    fi
    local pages_mode=false blog_enabled=true
    if [[ -d "${site_dir}/pages" || -L "${site_dir}/pages" ]]; then
        if ! ensure_zeta_page_home "$site_dir" "$config_file"; then
            rm -rf -- "$staging_dir"
            return 1
        fi
    fi
    if [[ -f "${site_dir}/pages/index.md" ]]; then
        pages_mode=true
        [[ "$(get_site_yaml_prop "$config_file" build blog true)" == false ]] && blog_enabled=false
    fi
    local posts_list_html=""
    local md_file
    local built_count=0
    declare -A generated_paths=()

    if [[ "$blog_enabled" == false ]]; then md_files=(); fi
    for md_file in "${md_files[@]}"; do
        declare -A post=()
        get_post_metadata "$md_file" post "$site_author"

        local html_post_title html_post_author html_post_date html_post_iso_date html_post_desc
        html_post_title=$(html_escape "${post[title]}")
        html_post_author=$(html_escape "${post[author]}")
        html_post_date=$(html_escape "${post[human_date]}")
        html_post_iso_date=$(html_escape "${post[date]}")
        html_post_desc=$(html_escape "${post[description]}")
        local html_post_external_url=""
        if [[ -n "${post[external_url]}" ]]; then
            if ! is_safe_public_link "${post[external_url]}"; then
                msg_error "Unsafe external_url in ${md_file}."
                rm -rf -- "$staging_dir"
                return 1
            fi
            html_post_external_url=$(html_escape "${post[external_url]}")
        fi

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

        if [[ "$pages_mode" == true ]]; then
            local article_nav
            article_nav=$(zeta_pages_navigation "$site_dir" "$rel_root" blog "$blog_enabled")
            pandoc_opts+=(-V "page_navigation=${article_nav}")
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
            -V "path=${rel_path}" \
            -V "description=${html_post_desc}" \
            -V "external_url=${html_post_external_url}"); then
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
            index.html) [[ "$pages_mode" == true ]] && continue ;;
            posts.html) [[ "$pages_mode" == true && "$blog_enabled" == false ]] && continue ;;
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
            -V "eyebrow=$(html_escape "$landing_eyebrow")"
            -V "primary_label=$(html_escape "$landing_primary_label")"
            -V "primary_url=$(html_escape "$landing_primary_url")"
            -V "secondary_label=$(html_escape "$landing_secondary_label")"
            -V "secondary_url=$(html_escape "$landing_secondary_url")"
            -V "hero_image=$(html_escape "$landing_hero_image")"
            -V "hero_alt=$(html_escape "$landing_hero_alt")"
            -V "landing_content=${landing_content}"
        )
        if [[ "$pages_mode" == true && "$base_html" == posts.html ]]; then
            local archive_nav
            archive_nav=$(zeta_pages_navigation "$site_dir" "./" blog "$blog_enabled")
            page_opts+=(-V "page_navigation=${archive_nav}")
        fi
        append_css_vars page_opts "" "${theme_dir}/styles" "${site_dir}/styles"
        if ! pandoc /dev/null "${page_opts[@]}" -o "${output_dir}/${base_html}"; then
            msg_error "Pandoc failed while rendering page template: ${base_html}"
            rm -rf -- "$staging_dir"
            return 1
        fi
    done < <(find "$theme_dir" -maxdepth 1 -type f -name '*.html' -print | sort)

    if [[ "$pages_mode" == true ]]; then
        if ! zeta_render_markdown_pages "$site_dir" "$output_dir" "$site_url" "$theme_dir" "$site_title" "$site_desc" "$site_author" "$site_lang" "$blog_enabled" "$site_theme"; then
            rm -rf -- "$staging_dir"
            return 1
        fi
    fi
    [[ -f "${output_dir}/index.html" ]] || {
        msg_error "Theme '${site_theme}' did not generate index.html."
        rm -rf -- "$staging_dir"
        return 1
    }

    local sitemap_content_dir="$content_dir"
    [[ "$blog_enabled" == false ]] && sitemap_content_dir="${site_dir}/.zeta-no-posts"
    if ! write_robots_txt "$output_dir" "$site_url" || \
       ! generate_sitemap "$sitemap_content_dir" "$output_dir" "$site_url" "$site_author" "${theme_dir}/sitemap.xsl"; then
        msg_error "Failed to generate robots.txt or sitemap.xml."
        rm -rf -- "$staging_dir"
        return 1
    fi

    if [[ "$pages_mode" == true ]]; then
        # Append page URLs inside the generated sitemap, before closing urlset.
        local page_md page_slug page_xml="${output_dir}/.pages-sitemap"
        : > "$page_xml"
        for page_md in "${site_dir}/pages/"*.md; do
            [[ -f "$page_md" ]] || continue
            page_slug=$(basename "$page_md" .md)
            [[ "$page_slug" == index ]] && continue
            [[ "$(extract_frontmatter_property "$page_md" draft 2>/dev/null || true)" == true ]] && continue
            printf '  <url><loc>%s/%s/</loc></url>\n' "$(xml_escape "$site_url")" "$page_slug" >> "$page_xml"
        done
        if [[ -s "$page_xml" ]]; then
            local smap="${output_dir}/sitemap.xml"
            sed '/<\/urlset>/d' "$smap" > "${smap}.new"
            cat "$page_xml" >> "${smap}.new"
            printf '</urlset>\n' >> "${smap}.new"
            mv -- "${smap}.new" "$smap"
        fi
        rm -f "$page_xml"
        if [[ "$blog_enabled" == false ]]; then
            # Blog-free mode excludes article URLs and archives from publication.
            rm -rf -- "${output_dir}/posts"
        fi
    fi

    # Generate category and tag archives before SEO.
    if [[ "$blog_enabled" == true ]]; then
        local tax_map="${output_dir}/.zeta-taxonomy.tsv" tax_md category tax_slug tax_label tag
        : > "$tax_map"
        for tax_md in "${md_files[@]}"; do
            declare -A tax_post=()
            get_post_metadata "$tax_md" tax_post "$site_author"
            local tax_route="posts/${tax_post[year]}/${tax_post[slug]}.html"
            category=$(extract_frontmatter_property "$tax_md" category 2>/dev/null || true)
            if [[ -n "$category" ]]; then
                tax_slug=$(slugify "$category")
                [[ -n "$tax_slug" ]] || { msg_error "Invalid category: $tax_md"; rm -rf -- "$staging_dir"; return 1; }
                printf '%s\tcategory\t%s\t%s\n' "$tax_route" "$tax_slug" "$category" >> "$tax_map"
            fi
            local -a tax_tags=()
            IFS=',' read -r -a tax_tags <<< "${tax_post[tags]}"
            for tag in "${tax_tags[@]}"; do
                tax_label=$(trim_yaml_value "$tag")
                [[ -n "$tax_label" ]] || continue
                tax_slug=$(slugify "$tax_label")
                [[ -n "$tax_slug" ]] || { msg_error "Invalid tag: $tax_md"; rm -rf -- "$staging_dir"; return 1; }
                printf '%s\ttag\t%s\t%s\n' "$tax_route" "$tax_slug" "$tax_label" >> "$tax_map"
            done
        done
        if [[ -s "$tax_map" ]]; then
            local taxonomy_filter="${TEMPLATES_DIR}/common/filters/taxonomies.lua"
            if [[ ! -f "$taxonomy_filter" ]] || ! printf '' | pandoc -f markdown -t plain --lua-filter="$taxonomy_filter" \
                -M "zeta_taxonomy_output=$output_dir" -M "zeta_taxonomy_url=$site_url" \
                -M "zeta_taxonomy_title=$site_title" -M "zeta_taxonomy_language=$site_lang" -o /dev/null; then
                msg_error "Taxonomy generation failed."; rm -rf -- "$staging_dir"; return 1
            fi
        fi
        rm -f -- "$tax_map"
    fi

    # Normalize search metadata while the build is staged; never modify live public/.
    local seo_filter="${TEMPLATES_DIR}/common/filters/seo-publish.lua"
    if [[ ! -f "$seo_filter" ]] || ! printf '' | pandoc -f markdown -t plain --lua-filter="$seo_filter" \
        -M "zeta_seo_output=$output_dir" -M "zeta_seo_url=$site_url" \
        -M "zeta_seo_title=$site_title" -M "zeta_seo_description=$site_desc" \
        -M "zeta_seo_image=$(get_site_yaml_prop "$config_file" site image "")" -o /dev/null; then
        msg_error "Shared SEO metadata generation failed."
        rm -rf -- "$staging_dir"; return 1
    fi

    local update_map="${output_dir}/.zeta-updates.tsv" update_md updated update_slug
    : > "$update_map"
    if [[ "$pages_mode" == true ]]; then
        for update_md in "${site_dir}/pages/"*.md; do
            [[ -f "$update_md" ]] || continue
            [[ "$(extract_frontmatter_property "$update_md" draft 2>/dev/null || true)" == true ]] && continue
            updated=$(extract_frontmatter_property "$update_md" updated 2>/dev/null || true)
            [[ -n "$updated" ]] || continue
            [[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { msg_error "Invalid updated date in $update_md"; rm -rf -- "$staging_dir"; return 1; }
            update_slug=$(basename "$update_md" .md)
            if [[ "$update_slug" == index ]]; then printf 'index.html\t%s\n' "$updated" >> "$update_map"
            else printf '%s/index.html\t%s\n' "$update_slug" "$updated" >> "$update_map"; fi
        done
    fi
    if [[ "$blog_enabled" == true ]]; then
        for update_md in "${md_files[@]}"; do
            declare -A update_post=()
            get_post_metadata "$update_md" update_post "$site_author"
            updated=$(extract_frontmatter_property "$update_md" updated 2>/dev/null || true)
            [[ -n "$updated" ]] || continue
            [[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { msg_error "Invalid updated date in $update_md"; rm -rf -- "$staging_dir"; return 1; }
            printf 'posts/%s/%s.html\t%s\n' "${update_post[year]}" "${update_post[slug]}" "$updated" >> "$update_map"
        done
    fi
    local extra_filter="${TEMPLATES_DIR}/common/filters/publish-extras.lua"
    if [[ ! -f "$extra_filter" ]] || ! printf '' | pandoc -f markdown -t plain --lua-filter="$extra_filter" \
        -M "zeta_extra_output=$output_dir" -M "zeta_extra_url=$site_url" \
        -M "zeta_extra_title=$site_title" -M "zeta_extra_description=$site_desc" \
        -M "zeta_extra_author=$site_author" -M "zeta_extra_language=$site_lang" \
        -M "zeta_extra_blog=$blog_enabled" -o /dev/null; then
        msg_error "RSS/Atom, JSON-LD or sitemap generation failed."
        rm -rf -- "$staging_dir"; return 1
    fi
    rm -f -- "$update_map"

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
        if [[ -e "$previous_output" ]]; then mv -- "$previous_output" "$final_output_dir" 2>/dev/null || true; fi
        rm -rf -- "$staging_dir"
        return 1
    fi
    rm -rf -- "$previous_output"

    msg_success "Site '${site_slug}' built: ${built_count} post(s) -> ${final_output_dir}"
}

# Flat Markdown pages are opt-in: no pages/index.md means legacy behavior.
zeta_pages_navigation() {
    local site_dir="$1" prefix="$2" active="$3" blog_enabled="$4"
    local pages_dir="${site_dir}/pages" source slug nav title order rows=""
    for source in "$pages_dir"/*.md; do
        [[ -f "$source" && ! -L "$source" ]] || continue
        slug=$(basename "$source" .md)
        [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || continue
        [[ "$(extract_frontmatter_property "$source" draft 2>/dev/null || true)" == "true" ]] && continue
        nav=$(extract_frontmatter_property "$source" nav 2>/dev/null || true)
        [[ "$nav" == "false" ]] && continue
        title=$(extract_frontmatter_property "$source" menu_title 2>/dev/null || true)
        [[ -n "$title" ]] || title=$(extract_frontmatter_property "$source" title 2>/dev/null || true)
        [[ -n "$title" ]] || title="$slug"
        title="${title//|/ }"
        order=$(extract_frontmatter_property "$source" nav_order 2>/dev/null || true)
        [[ "$order" =~ ^[0-9]{1,3}$ ]] || order=50
        [[ "$slug" == "index" ]] && order=0
        rows+="$(printf '%04d|%s|%s\n' "$order" "$slug" "$title")"$'\n'
    done
    local rendered="" href marker
    while IFS='|' read -r order slug title; do
        [[ -n "$slug" ]] || continue
        if [[ "$slug" == "index" ]]; then href="${prefix}index.html"
        else href="${prefix}${slug}/"; fi
        marker=""
        [[ "$active" == "$slug" ]] && marker=' aria-current="page"'
        rendered+="<a href=\"$(html_escape "$href")\"${marker}>$(html_escape "$title")</a> "
    done < <(printf '%s' "$rows" | LC_ALL=C sort -t '|' -k1,1n -k2,2)
    if [[ "$blog_enabled" == "true" ]]; then
        marker=""
        [[ "$active" == "blog" ]] && marker=' aria-current="page"'
        rendered+="<a href=\"$(html_escape "${prefix}posts.html")\"${marker}>Blog</a>"
    fi
    printf '%s' "$rendered"
}
zeta_render_markdown_pages() {
    local site_dir="$1" output_dir="$2" site_url="$3" theme_dir="$4"
    local site_title="$5" site_desc="$6" site_author="$7" site_lang="$8" blog_enabled="$9"
    local theme_name="${10}"
    local pages_dir="${site_dir}/pages" source slug draft title desc destination prefix canonical depth nav
    [[ -f "${pages_dir}/index.md" && ! -L "${pages_dir}/index.md" ]] || {
        msg_error "pages/index.md is required for a Markdown-driven site."; return 1
    }
    for source in "$pages_dir"/*.md; do
        [[ -f "$source" ]] || continue
        [[ ! -L "$source" ]] || { msg_error "Symlink pages are not allowed: $source"; return 1; }
        slug=$(basename "$source" .md)
        [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
            msg_error "Invalid page filename: $source"; return 1
        }
        if [[ "$slug" == "posts" || "$slug" == "blog" ]]; then
            msg_error "Reserved page slug: $slug"; return 1
        fi
        draft=$(extract_frontmatter_property "$source" draft 2>/dev/null || true)
        if [[ "$draft" == "true" ]]; then
            [[ "$slug" != "index" ]] || { msg_error "The homepage cannot be a draft."; return 1; }
            continue
        fi
        title=$(extract_frontmatter_property "$source" title 2>/dev/null || true)
        [[ -n "$title" ]] || title="$slug"
        desc=$(extract_frontmatter_property "$source" description 2>/dev/null || true)
        [[ -n "$desc" ]] || desc="$site_desc"
        if [[ "$slug" == "index" ]]; then
            destination="${output_dir}/index.html"; prefix=""; depth=0; canonical="${site_url}/"
        else
            destination="${output_dir}/${slug}/index.html"; prefix="../"; depth=1
            canonical="${site_url}/${slug}/"
        fi
        mkdir -p "$(dirname "$destination")"
        nav=$(zeta_pages_navigation "$site_dir" "$prefix" "$slug" "$blog_enabled")
        local options=(
            --from=markdown-raw_html --to=html5 --standalone --wrap=none
            "--template=${TEMPLATES_DIR}/common/pages/page.html"
            "--lua-filter=${TEMPLATES_DIR}/common/filters/page-links.lua"
            -M "zeta_page_depth=${depth}"
            -V "title=$(html_escape "$title")"
            -V "description=$(html_escape "$desc")"
            -V "site_title=$(html_escape "$site_title")"
            -V "site_author=$(html_escape "$site_author")"
            -V "site_lang=$(html_escape "$site_lang")"
            -V "site_theme=$(html_escape "$theme_name")"
            -V "rel_root=${prefix}"
            -V "page_slug=${slug}"
            -V "canonical=$(html_escape "$canonical")"
            -V "page_navigation=${nav}"
        )
        append_css_vars options "$prefix" "${theme_dir}/styles" "${site_dir}/styles"
        if ! pandoc "$source" "${options[@]}" -o "$destination"; then
            msg_error "Failed to render Markdown page: $source"; return 1
        fi
    done
}


# Repair a partially created multipage site without overwriting its sources.
# Called by build and new-page; sites with no pages/ remain untouched.
ensure_zeta_page_home() {
    local site_dir="$1" config_file="$2"
    local pages_dir="${site_dir}/pages"
    local homepage="${pages_dir}/index.md"
    [[ -d "$pages_dir" || -L "$pages_dir" ]] || return 0
    if [[ -L "$pages_dir" ]]; then
        msg_error "Unsafe symbolic link for Markdown pages: $pages_dir"
        return 1
    fi
    if [[ -L "$homepage" ]]; then
        msg_error "Unsafe symbolic link for homepage: $homepage"
        return 1
    fi
    [[ -e "$homepage" ]] && return 0

    local template="${TEMPLATES_DIR}/common/pages/index.md"
    [[ -f "$template" ]] || { msg_error "Missing Markdown homepage template: $template"; return 1; }
    local content title description title_yaml desc_yaml
    content=$(<"$template")
    [[ "$content" == *'__ZETA_SITE_TITLE__'* && "$content" == *'__ZETA_SITE_DESCRIPTION__'* ]] || {
        msg_error "Homepage template is missing required title/description placeholders."
        return 1
    }
    title=$(get_site_yaml_prop "$config_file" site title "$(basename "$site_dir")")
    description=$(get_site_yaml_prop "$config_file" site description "Built with Zeta")
    title_yaml=$(yaml_quote "$title")
    desc_yaml=$(yaml_quote "$description")
    content="${content%%__ZETA_SITE_TITLE__*}${title_yaml}${content#*__ZETA_SITE_TITLE__}"
    content="${content%%__ZETA_SITE_DESCRIPTION__*}${desc_yaml}${content#*__ZETA_SITE_DESCRIPTION__}"
    # noclobber also guards against another process creating the file now.
    if ! ( set -C; printf '%s\n' "$content" > "$homepage" ); then
        msg_error "Could not create missing homepage without overwriting: $homepage"
        return 1
    fi
    msg_info "Created missing Markdown homepage: $homepage"
}
