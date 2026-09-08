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

build_site() {
    local site_slug="${1:-}"

    if [[ -z "$site_slug" ]]; then
        echo "❌ Error: No site slug provided to build_site." >&2
        return 1
    fi

    local current_dir="${CURRENT_DIR:-$(pwd)}"
    local sites_dir="${SITES_DIR:-${current_dir}/sites}"
    local site_dir="${sites_dir}/${site_slug}"
    
    # 1. Detección flexible de config.yaml o config.yml
    local config_file="${site_dir}/config.yaml"
    if [[ ! -f "$config_file" && -f "${site_dir}/config.yml" ]]; then
        config_file="${site_dir}/config.yml"
    fi

    if [[ ! -d "$site_dir" ]]; then
        echo "❌ Error: Site directory '${site_dir}' does not exist." >&2
        return 1
    fi

    echo -e "\n🚀 Starting build process for site: '${site_slug}'"

    # 2. Leer propiedades desde YAML
    local site_title site_desc site_author site_lang site_theme pandoc_theme

    site_title=$(get_site_yaml_prop "$config_file" "site" "title" "$site_slug")
    site_desc=$(get_site_yaml_prop "$config_file" "site" "description" "Blog generado con Zeta")
    site_author=$(get_site_yaml_prop "$config_file" "site" "author" "Usuario")
    site_lang=$(get_site_yaml_prop "$config_file" "site" "language" "es")
    site_theme=$(get_site_yaml_prop "$config_file" "theme" "name" "basic")
    pandoc_theme=$(get_site_yaml_prop "$config_file" "theme" "pandoc_theme" "zenburn")

    # 3. Localizar plantilla del tema
    local theme_dir="$TEMPLATES_DIR/$site_theme"

    echo "⚙️  Title: ${site_title}"
    echo "🎨 Active Theme: ${site_theme} (${theme_dir})"
    echo "💡 Syntax Highlight: ${pandoc_theme}"

    # 4. Copiar recursos estáticos (Assets y CSS)
    mkdir -p "${site_dir}/assets" "${site_dir}/styles"
    cp -r "${TEMPLATES_DIR}/common/assets/"* "${site_dir}/assets/" 2>/dev/null || true
    cp -r "${TEMPLATES_DIR}/common/styles/"* "${site_dir}/styles/" 2>/dev/null || true

    # 5. Determinar la plantilla HTML de artículo
    local article_template=""
    if [[ -f "${theme_dir}/article.html" ]]; then
        article_template="${theme_dir}/article.html"
    elif [[ -f "${theme_dir}/post.html" ]]; then
        article_template="${theme_dir}/post.html"
    elif [[ -f "${theme_dir}/single.html" ]]; then
        article_template="${theme_dir}/single.html"
    fi

    # 6. Búsqueda recursiva de archivos Markdown
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

    # 7. Procesar cada archivo Markdown
    for md_file in "${md_files[@]}"; do
        local raw_filename
        raw_filename=$(basename "$md_file" .md)

        local title author date human_date description year slug

        title=$(extract_frontmatter_property "$md_file" "title" 2>/dev/null || echo "")
        author=$(extract_frontmatter_property "$md_file" "author" 2>/dev/null || echo "")
        date=$(extract_frontmatter_property "$md_file" "date" 2>/dev/null || echo "")
        human_date=$(extract_frontmatter_property "$md_file" "human_date" 2>/dev/null || echo "")
        description=$(extract_frontmatter_property "$md_file" "description" 2>/dev/null || echo "")
        year=$(extract_frontmatter_property "$md_file" "year" 2>/dev/null || echo "")
        slug=$(extract_frontmatter_property "$md_file" "slug" 2>/dev/null || echo "")

        if [[ -z "$slug" ]]; then
            if [[ "$raw_filename" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}-(.*)$ ]]; then
                slug="${BASH_REMATCH[2]}"
            elif [[ "$raw_filename" =~ ^([0-9]{4})-(.*)$ ]]; then
                slug="${BASH_REMATCH[2]}"
            else
                slug="$raw_filename"
            fi
        fi

        if [[ -z "$year" ]]; then
            if [[ "$date" =~ ^([0-9]{4}) ]]; then
                year="${BASH_REMATCH[1]}"
            elif [[ "$raw_filename" =~ ^([0-9]{4}) ]]; then
                year="${BASH_REMATCH[1]}"
            else
                local parent_dir
                parent_dir=$(basename "$(dirname "$md_file")")
                if [[ "$parent_dir" =~ ^[0-9]{4}$ ]]; then
                    year="$parent_dir"
                else
                    year=$(date +%Y)
                fi
            fi
        fi

        [[ -z "$title" ]] && title="$slug"
        [[ -z "$author" ]] && author="$site_author"
        [[ -z "$human_date" ]] && human_date="${date:-$year}"

        echo "   -> Compiling post: ${raw_filename}.md => posts/${year}/${slug}.html"

        local post_target_dir="${site_dir}/posts/${year}"
        mkdir -p "$post_target_dir"
        local output_file="${post_target_dir}/${slug}.html"

        local rel_path="posts/${year}/${slug}.html"
        local rel_root="../../"

        local pandoc_opts=(
            --read=markdown
            --table-of-contents
            --toc-depth=2
            --preserve-tabs
            --standalone
            --highlight-style="${pandoc_theme}"
            -V "path=${rel_path}"
            -V "rel_root=${rel_root}"
            -V "title=${title}"
            -V "author=${author}"
            -V "date=${human_date}"
            -V "year=${year}"
            -V "slug=${slug}"
            -V "description=${description}"
            -V "site_title=${site_title}"
            -V "site_author=${site_author}"
            -V "site_lang=${site_lang}"
        )

        if [[ -n "$article_template" && -f "$article_template" ]]; then
            pandoc_opts+=(--template="${article_template}")
        fi

        if pandoc "${md_file}" "${pandoc_opts[@]}" -o "${output_file}" 2>/dev/null; then
            if grep -q "{{BODY}}" "${output_file}" 2>/dev/null; then
                local body_html
                body_html=$(pandoc --from=markdown --to=html "$md_file")
                local template_content
                template_content=$(cat "$article_template")

                local rendered_post="$template_content"
                rendered_post="${rendered_post//\{\{SITE_TITLE\}\}/$site_title}"
                rendered_post="${rendered_post//\{\{SITE_AUTHOR\}\}/$site_author}"
                rendered_post="${rendered_post//\{\{TITLE\}\}/$title}"
                rendered_post="${rendered_post//\{\{AUTHOR\}\}/$author}"
                rendered_post="${rendered_post//\{\{DATE\}\}/$human_date}"
                rendered_post="${rendered_post//\{\{YEAR\}\}/$year}"
                rendered_post="${rendered_post//\{\{SLUG\}\}/$slug}"
                rendered_post="${rendered_post//\{\{DESCRIPTION\}\}/$description}"
                rendered_post="${rendered_post//\{\{REL_ROOT\}\}/$rel_root}"
                rendered_post="${rendered_post//\{\{PATH\}\}/$rel_path}"
                rendered_post="${rendered_post//\{\{BODY\}\}/$body_html}"

                echo "$rendered_post" > "$output_file"
            fi
        else
            local body_html
            body_html=$(pandoc --from=markdown --to=html "$md_file" 2>/dev/null || cat "$md_file")
            echo "<!DOCTYPE html><html><head><title>${title}</title></head><body>${body_html}</body></html>" > "$output_file"
        fi

        # Acumular HTML para la lista de publicaciones del índice del sitio
        posts_list_html+="          <li class=\"post-item\">\n"
        posts_list_html+="            <span class=\"post-date\">[${human_date}]</span>\n"
        posts_list_html+="            <a href=\"/${site_slug}/${rel_path}\" class=\"post-link\">${title}</a>\n"
        posts_list_html+="          </li>\n"

    done

    # 8. Renderizar plantillas HTML principales del sitio (index.html, etc.)
    if [[ -d "$theme_dir" ]]; then
        while IFS= read -r -d '' html_file; do
            local base_html
            base_html=$(basename "$html_file")
            
            # Omitir la plantilla dedicada a artículos
            if [[ "$html_file" == "$article_template" ]]; then
                continue
            fi

            local html_content
            html_content=$(cat "$html_file")

            html_content="${html_content//\{\{SITE_TITLE\}\}/$site_title}"
            html_content="${html_content//\{\{SITE_DESC\}\}/$site_desc}"
            html_content="${html_content//\{\{SITE_AUTHOR\}\}/$site_author}"
            html_content="${html_content//\{\{SITE_LANG\}\}/$site_lang}"
            html_content="${html_content//\{\{POSTS_LIST\}\}/$posts_list_html}"

            printf "%b" "$html_content" > "${site_dir}/${base_html}"
        done < <(find "$theme_dir" -maxdepth 1 -type f -name "*.html" -print0)
    fi

    echo "✅ Site '${site_slug}' built successfully!"
}