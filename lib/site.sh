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
    local base_url="/${site_slug}"

    declare -A posts_by_year
    local post_count=0

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
        tags=$(extract_frontmatter_tags "$md_file" 2>/dev/null || echo "")

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
            --from=markdown
            --to=html
            --table-of-contents
            --toc-depth=2
            --preserve-tabs
            --standalone
            --syntax-highlighting="${pandoc_theme}"
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

        # Asignar CSS dinámicamente como bucle para Pandoc
        if [[ -d "${site_dir}/styles" ]]; then
            for css_file in "${site_dir}/styles"/*.css; do
                [[ -f "$css_file" ]] || continue
                pandoc_opts+=(-V "css=${rel_root}styles/$(basename "$css_file")")
            done
        fi

        # Asignar tags dinámicamente como bucle para Pandoc
        if [[ -n "$tags" ]]; then
            local clean_tags
            clean_tags=$(echo "$tags" | tr -d '[]"' | tr ',' ' ')
            for tag in $clean_tags; do
                pandoc_opts+=(-V "tags=${tag}")
            done
        fi

        # Compilación real con Pandoc
        pandoc "${md_file}" "${pandoc_opts[@]}" -o "${output_file}"

        posts_list_html+="          <li class=\"post-item\">\n"
        posts_list_html+="            <span class=\"post-date\">[${human_date}]</span>\n"
        posts_list_html+="            <a href=\"/${site_slug}/${rel_path}\" class=\"post-link\">${title}</a>\n"
        posts_list_html+="          </li>\n"

    done
    
    # 8. Renderizar plantillas raíz del tema con Pandoc (index.html, etc.)
    if [[ -d "$theme_dir" ]]; then
        while IFS= read -r -d '' html_file; do
            local base_html
            base_html=$(basename "$html_file")
            
            if [[ -n "$article_template" && "$html_file" == "$article_template" ]]; then
                continue
            fi

            local index_opts=(
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

            pandoc /dev/null "${index_opts[@]}" -o "${site_dir}/${base_html}"
        done < <(find "$theme_dir" -maxdepth 1 -type f -name "*.html" -print0)
    fi
    
    echo "✅ Site '${site_slug}' built successfully!"
}