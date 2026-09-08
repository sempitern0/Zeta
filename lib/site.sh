# shellcheck disable=SC1091,SC2034,SC2155

get_site_yaml_prop() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default_val="${4:-}"

    [[ -f "$file" ]] || { echo "$default_val"; return 0; }

    local val

    val=$(awk -v sec="${section}:" -v k="${key}:" '
        $0 ~ "^"sec { in_sec=1; next }
        in_sec && /^[^ \t]/ { in_sec=0 }
        in_sec && $1 == k {
            $1="";
            sub(/^ +/, "");
            gsub(/^["'\''"]|["'\''"]$/, "");
            print;
            exit
        }
    ' "$file" 2>/dev/null)

    if [[ -n "$val" ]]; then
        echo "$val"
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
    raw_filename=$(basename "$md_file" .md)
    meta["raw_filename"]="$raw_filename"

    meta["title"]=$(extract_frontmatter_property "$md_file" "title" 2>/dev/null || echo "")
    meta["author"]=$(extract_frontmatter_property "$md_file" "author" 2>/dev/null || echo "")
    meta["date"]=$(extract_frontmatter_property "$md_file" "date" 2>/dev/null || echo "")
    meta["human_date"]=$(extract_frontmatter_property "$md_file" "human_date" 2>/dev/null || echo "")
    meta["description"]=$(extract_frontmatter_property "$md_file" "description" 2>/dev/null || echo "")
    meta["year"]=$(extract_frontmatter_property "$md_file" "year" 2>/dev/null || echo "")
    meta["slug"]=$(extract_frontmatter_property "$md_file" "slug" 2>/dev/null || echo "")
    meta["tags"]=$(extract_frontmatter_tags "$md_file" 2>/dev/null || echo "")

    if [[ -z "${meta["slug"]}" ]]; then
        if [[ "$raw_filename" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}-(.*)$ ]]; then
            meta["slug"]="${BASH_REMATCH[2]}"
        elif [[ "$raw_filename" =~ ^([0-9]{4})-(.*)$ ]]; then
            meta["slug"]="${BASH_REMATCH[2]}"
        else
            meta["slug"]="$raw_filename"
        fi
    fi

    if [[ -z "${meta["year"]}" ]]; then
        if [[ "${meta["date"]}" =~ ^([0-9]{4}) ]]; then
            meta["year"]="${BASH_REMATCH[1]}"
        elif [[ "$raw_filename" =~ ^([0-9]{4}) ]]; then
            meta["year"]="${BASH_REMATCH[1]}"
        else
            local parent_dir
            parent_dir=$(basename "$(dirname "$md_file")")
            if [[ "$parent_dir" =~ ^[0-9]{4}$ ]]; then
                meta["year"]="$parent_dir"
            else
                meta["year"]=$(date +%Y)
            fi
        fi
    fi

    # Fallbacks seguros
    meta["title"]="${meta["title"]:-${meta["slug"]}}"
    meta["author"]="${meta["author"]:-$site_author_fallback}"
    meta["human_date"]="${meta["human_date"]:-${meta["date"]:-${meta["year"]}}}"

    return 0
}

update_robots_txt() {
    local site_slug="${1:-}"

    if [[ -z "$site_slug" ]]; then
        echo "❌ Error: No site slug provided to update_robots_txt." >&2
        return 1
    fi

    local target_robots="${SITES_DIR}/${site_slug}/robots.txt"  
    local site_prefix="${SITES_URL%/}"
    local site_path="${site_slug#/}"
    local clean_base_url="${site_prefix}/${site_path}"

    if [[ -f "$target_robots" ]]; then
        sed -i "s|^Sitemap:.*|Sitemap: ${clean_base_url}/sitemap.xml|g" "$target_robots"
    fi
}
generate_sitemap() {
    local site_slug="${1:-}"
    local site_theme="${2:-basic}"

    if [[ -z "$site_slug" ]]; then
        echo "❌ Error: No site slug provided to generate_sitemap." >&2
        return 1
    fi

    local site_dir="${SITES_DIR}/${site_slug}"
    local posts_dir="${site_dir}/posts"
    local sitemap_file="${site_dir}/sitemap.xml"
    local target_xsl="${site_dir}/sitemap.xsl"
    
    local theme_xsl="${TEMPLATES_DIR}/${site_theme}/sitemap.xsl"
    local common_xsl="${TEMPLATES_DIR}/common/sitemap.xsl"

    local site_prefix="${SITES_URL%/}"
    local site_path="${site_slug#/}"
    local clean_base_url="${site_prefix}/${site_path}"
    local today
    today=$(date +%Y-%m-%d)

    echo "🗺️  Generating sitemap.xml for '${site_slug}' (Theme: ${site_theme})..."

    if [[ -f "$theme_xsl" ]]; then
        cp "$theme_xsl" "$target_xsl"
    elif [[ -f "$common_xsl" ]]; then
        cp "$common_xsl" "$target_xsl"
    else
        echo "⚠️  Warning: No sitemap.xsl found in theme or common. Proceeding without stylesheet." >&2
    fi

    cat <<EOF > "$sitemap_file"
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="${clean_base_url}/sitemap.xsl"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${clean_base_url}/</loc>
    <lastmod>${today}</lastmod>
    <priority>1.00</priority>
  </url>
EOF

    if [[ -d "$posts_dir" ]]; then
        while IFS= read -r -d '' html_file; do
            local rel_path="${html_file#"${site_dir}/"}"
            local mod_date
            mod_date=$(date -r "$html_file" +%Y-%m-%d 2>/dev/null || echo "$today")

            cat <<EOF >> "$sitemap_file"
  <url>
    <loc>${clean_base_url}/${rel_path}</loc>
    <lastmod>${mod_date}</lastmod>
    <priority>0.80</priority>
  </url>
EOF
        done < <(find "$posts_dir" -type f -name "*.html" -print0 2>/dev/null)
    fi

    # 4. Cierre de la etiqueta principal
    echo "</urlset>" >> "$sitemap_file"
}

build_site() {
    local site_slug="${1:-}"

    if [[ -z "$site_slug" ]]; then
        echo "❌ Error: No site slug provided to build_site." >&2
        return 1
    fi

    local site_dir="${SITES_DIR}/${site_slug}"
    local config_file="${site_dir}/config.yaml"

    if [[ ! -d "$site_dir" ]]; then
        echo "❌ Error: Site directory '${site_dir}' does not exist." >&2
        return 1
    fi

    echo -e "\n🚀 Starting build process for site: '${site_slug}'"

    local site_title site_desc site_author site_lang site_theme pandoc_theme

    site_title=$(get_site_yaml_prop "$config_file" "site" "title" "$site_slug")
    site_desc=$(get_site_yaml_prop "$config_file" "site" "description" "Blog generado con Zeta")
    site_author=$(get_site_yaml_prop "$config_file" "site" "author" "Usuario")
    site_lang=$(get_site_yaml_prop "$config_file" "site" "language" "es")
    site_theme=$(get_site_yaml_prop "$config_file" "theme" "name" "basic")
    pandoc_theme=$(get_site_yaml_prop "$config_file" "theme" "pandoc_theme" "zenburn")

    local theme_dir="$TEMPLATES_DIR/$site_theme"

    echo -e "⚙️  Title: ${site_title}"
    echo -e "🎨 Active Theme: ${site_theme} (${theme_dir})"
    echo -e "💡 Syntax Highlight: ${pandoc_theme}"

    mkdir -p "${site_dir}/assets" "${site_dir}/styles"
    cp -r "${TEMPLATES_DIR}/common/"{assets,styles} "${site_dir}/" 2>/dev/null || true
    cp "${TEMPLATES_DIR}/robots.txt" "${site_dir}/" 2>/dev/null || true

    local article_template="${theme_dir}/article.html"
    local post_link_template="${theme_dir}/post_link.html"

    local md_files=()

    while IFS= read -r -d '' file; do
        md_files+=("$file")
    done < <(find "$site_dir" -type f -name "*.md" \
        ! -path "*/posts/*" \
        ! -path "*/templates/*" \
        ! -path "*/assets/*" \
        ! -path "*/public/*" \
        ! -path "*/.*" -print0 2>/dev/null)

    local posts_list_html=""
    local base_url="/${site_slug}"

    for md_file in "${md_files[@]}"; do
        declare -A post
        get_post_metadata "$md_file" post "$site_author"

        echo "   -> Compiling post: ${post[raw_filename]}.md => posts/${post[year]}/${post[slug]}.html"

        local rel_path="posts/${post[year]}/${post[slug]}.html"
        local rel_root="../../"
        local output_file="${site_dir}/${rel_path}"

        mkdir -p "$(dirname "$output_file")"

        local pandoc_opts=(
            --from=markdown
            --to=html
            --table-of-contents
            --toc-depth=2
            --preserve-tabs
            --standalone
            --syntax-highlighting="${pandoc_theme}"
            -V "path=${rel_path}"
            -V "rel_root=${rel_root}"
            -V "title=${post[title]}"
            -V "author=${post[author]}"
            -V "date=${post[human_date]}"
            -V "year=${post[year]}"
            -V "slug=${post[slug]}"
            -V "description=${post[description]}"
            -V "site_title=${site_title}"
            -V "site_author=${site_author}"
            -V "site_lang=${site_lang}"
        )

        if [[ -n "$article_template" && -f "$article_template" ]]; then
            pandoc_opts+=(--template="${article_template}")
        fi

        # Asignar CSS dinámicamente
        if [[ -d "${site_dir}/styles" ]]; then
            for css_file in "${site_dir}/styles"/*.css; do
                [[ -f "$css_file" ]] || continue
                pandoc_opts+=(-V "css=${rel_root}styles/$(basename "$css_file")")
            done
        fi

        # Asignar tags dinámicamente
        if [[ -n "${post[tags]}" ]]; then
            local clean_tags
            clean_tags=$(echo "${post[tags]}" | tr -d '[]"' | tr ',' ' ')
            for tag in $clean_tags; do
                pandoc_opts+=(-V "tags=${tag}")
            done
        fi

        pandoc "${md_file}" "${pandoc_opts[@]}" -o "${output_file}"

        # Renderizar cada item del post usando post_link.html
        local item_html
        item_html=$(pandoc /dev/null \
            --quiet \
            --template="${post_link_template}" \
            -V "title=${post[title]}" \
            -V "date=${post[human_date]}" \
            -V "base_url=${base_url}" \
            -V "path=${rel_path}")
        posts_list_html+="${item_html}"$'\n'

    done
    
    # Renderizar plantillas raíz del tema con Pandoc (index.html, etc.)
    if [[ -d "$theme_dir" ]]; then
        while IFS= read -r -d '' html_file; do
            local base_html
            base_html=$(basename "$html_file")
            
            # Omitir plantillas parciales/de artículo
            if [[ "$base_html" == "article.html" || "$base_html" == "post_link.html" ]]; then
                continue
            fi

            local index_opts=(
                --from=markdown
                --template="${html_file}"
                -V "site_lang=${site_lang}"
                -V "site_title=${site_title}"
                -V "site_desc=${site_desc}"
                -V "site_author=${site_author}"
                -V "posts_list=${posts_list_html}"
            )

            if [[ -d "${site_dir}/styles" ]]; then
                for css_file in "${site_dir}/styles"/*.css; do
                    [[ -f "$css_file" ]] || continue
                    index_opts+=(-V "css=./styles/$(basename "$css_file")")
                done
            fi

            pandoc /dev/null --quiet "${index_opts[@]}" -o "${site_dir}/${base_html}"
        done < <(find "$theme_dir" -maxdepth 1 -type f -name "*.html" -print0)
    fi
    
    update_robots_txt "$site_slug"
    generate_sitemap "$site_slug" "$site_theme"
    
    msg_success "✅ Site '${site_slug}' built successfully!"
}