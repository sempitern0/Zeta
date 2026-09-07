#!/usr/bin/env bash
# lib/site.sh - Motor de compilación individual por sitio
# shellcheck disable=SC1091,SC2034,SC2155

# Extractor de propiedades YAML (soporta formato clave: valor)
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

# Extractor de propiedades Frontmatter de archivos Markdown (.md)
extract_frontmatter_property() {
    local file="$1"
    local prop="$2"

    [[ -f "$file" ]] || return 1

    awk -v p="${prop}:" '
        BEGIN { in_fm=0 }
        /^---$/ {
            if (in_fm == 0) { in_fm=1; next }
            else { exit }
        }
        in_fm && $1 == p {
            $1="";
            sub(/^ +/, "");
            gsub(/^["'\''"]|["'\''"]$/, "");
            print;
            exit
        }
    ' "$file" 2>/dev/null
}

# Compila un único sitio según su slug
build_site() {
    local site_slug="${1:-}"

    if [[ -z "$site_slug" ]]; then
        echo "❌ Error: No site slug provided to build_site." >&2
        return 1
    fi

    local current_dir="${CURRENT_DIR:-$(pwd)}"
    local sites_dir="${SITES_DIR:-${current_dir}/sites}"
    local site_dir="${sites_dir}/${site_slug}"
    local config_file="${site_dir}/config.yml"

    if [[ ! -d "$site_dir" ]]; then
        echo "❌ Error: Site directory '${site_dir}' does not exist." >&2
        return 1
    fi

    echo -e "\n🚀 Starting build process for site: '${site_slug}'"

    # 1. Leer configuración desde config.yml
    local site_title site_desc site_author site_lang site_theme

    site_title=$(get_site_yaml_prop "$config_file" "site" "title" "$site_slug")
    site_desc=$(get_site_yaml_prop "$config_file" "site" "description" "Blog generado con Zeta")
    site_author=$(get_site_yaml_prop "$config_file" "site" "author" "Usuario")
    site_lang=$(get_site_yaml_prop "$config_file" "site" "language" "es")
    site_theme=$(get_site_yaml_prop "$config_file" "theme" "name" "basic")


    # 2. Localizar plantilla del tema
    local templates_dir="${TEMPLATES_DIR:-${current_dir}/templates}"
    local theme_dir=""

    if [[ -d "${templates_dir}/${site_theme}" ]]; then
        theme_dir="${templates_dir}/${site_theme}"
    elif [[ -d "${site_dir}/templates" ]]; then
        theme_dir="${site_dir}/templates"
    else
        theme_dir="${templates_dir}/basic"
    fi

    echo "⚙️  Title: ${site_title}"
    echo "🎨 Active Theme: ${site_theme} (${theme_dir})"
    echo "📁 Source Content: ${site_dir} (Recursive)"
    echo "🎯 Posts Output: ${site_dir}/posts/<year>/<slug>.html"

    # 3. Copiar recursos estáticos del tema si existen
    if [[ -d "${theme_dir}/assets" ]]; then
        mkdir -p "${site_dir}/assets"
        cp -r "${theme_dir}/assets/"* "${site_dir}/assets/" 2>/dev/null || true
    fi

    # 4. Determinar la plantilla HTML de artículo
    local article_template=""
    if [[ -f "${theme_dir}/article.html" ]]; then
        article_template="${theme_dir}/article.html"
    elif [[ -f "${theme_dir}/post.html" ]]; then
        article_template="${theme_dir}/post.html"
    elif [[ -f "${theme_dir}/single.html" ]]; then
        article_template="${theme_dir}/single.html"
    fi

    # 5. Búsqueda recursiva de archivos Markdown
    local md_files=()
    while IFS= read -r -d '' file; do
        md_files+=("$file")
    done < <(find "$site_dir" -type f -name "*.md" \
        ! -path "*/posts/*" \
        ! -path "*/templates/*" \
        ! -path "*/assets/*" \
        ! -path "*/public/*" \
        ! -path "*/.*" -print0 2>/dev/null)

    if (( ${#md_files[@]} == 0 )); then
        echo "⚠️  No .md files found in ${site_dir}"
        return 0
    fi

    # 6. Procesar cada archivo Markdown
    for md_file in "${md_files[@]}"; do
        local raw_filename
        raw_filename=$(basename "$md_file" .md)

        # Extraer metadatos de Frontmatter
        local title author date human_date description year slug

        title=$(extract_frontmatter_property "$md_file" "title")
        author=$(extract_frontmatter_property "$md_file" "author")
        date=$(extract_frontmatter_property "$md_file" "date")
        human_date=$(extract_frontmatter_property "$md_file" "human_date")
        description=$(extract_frontmatter_property "$md_file" "description")
        year=$(extract_frontmatter_property "$md_file" "year")
        slug=$(extract_frontmatter_property "$md_file" "slug")

        # A) Obtener Slug limpio
        if [[ -z "$slug" ]]; then
            if [[ "$raw_filename" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}-(.*)$ ]]; then
                slug="${BASH_REMATCH[2]}"
            elif [[ "$raw_filename" =~ ^([0-9]{4})-(.*)$ ]]; then
                slug="${BASH_REMATCH[2]}"
            else
                slug="$raw_filename"
            fi
        fi

        # B) Obtener Año con prioridad: 1. Frontmatter 'year' -> 2. Frontmatter 'date' -> 3. Nombre archivo -> 4. Nombre carpeta padre -> 5. Año actual
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

        # Ruta de destino final: sites/<misitio>/posts/<año>/<slug>.html
        local post_target_dir="${site_dir}/posts/${year}"
        mkdir -p "$post_target_dir"
        local output_file="${post_target_dir}/${slug}.html"

        # Cálculo de variables relativas
        local rel_path="posts/${year}/${slug}.html"
        local rel_root="../../"

        # Opciones completas de Pandoc con flags customizados
        local pandoc_opts=(
            --read=markdown
            --table-of-contents
            --toc-depth=2
            --preserve-tabs
            --standalone
            --highlight-style=zenburn
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

        # Si existe plantilla de artículo en el tema, la pasamos como opción a Pandoc
        if [[ -n "$article_template" && -f "$article_template" ]]; then
            pandoc_opts+=(--template="${article_template}")
        fi

        # Compilación con Pandoc
        if pandoc "${md_file}" "${pandoc_opts[@]}" -o "${output_file}" 2>/dev/null; then
            # Si la plantilla usa marcadores estilo Mustache {{BODY}} en lugar de variables de Pandoc ($body$)
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
            # Fallback en caso de fallo en la llamada de Pandoc
            local body_html
            body_html=$(pandoc --from=markdown --to=html "$md_file" 2>/dev/null || cat "$md_file")
            echo "<!DOCTYPE html><html><head><title>${title}</title></head><body>${body_html}</body></html>" > "$output_file"
        fi

    done

    echo "✅ Site '${site_slug}' posts built successfully!"
}