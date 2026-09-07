#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2155
set -euo pipefail

# ==============================================================================
# GLOBAL CONFIGURATION & PATHS
# ==============================================================================
SITE_NAME="${1:-mi-blog}"
SITE_DIR="${CURRENT_DIR}/sites/${SITE_NAME}"
POSTS_DIR="${SITE_DIR}/posts"
CONFIG_FILE="${SITE_DIR}/config.env"

# Load site-specific configuration if present
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Site Global Variables (can be overridden by site config.env or environment)
SITE_TITLE="${SITE_TITLE:-System Logs}"
SITE_AUTHOR="${SITE_AUTHOR:-s3r0s4pi3ns}"
SITE_LANG="${SITE_LANG:-es}"
SITE_DESC="${SITE_DESC:-Static blog generated with Bash and Pandoc}"
SITE_TEMPLATE="${SITE_TEMPLATE:-zen}"

# Resolve template directory priority:
# 1. templates/<SITE_TEMPLATE>
# 2. sites/<SITE_NAME>/templates (custom site-isolated template)
# 3. templates/ (fallback root)
if [[ -d "${CURRENT_DIR}/templates/${SITE_TEMPLATE}" ]]; then
    TEMPLATES_DIR="${CURRENT_DIR}/templates/${SITE_TEMPLATE}"
elif [[ -d "${SITE_DIR}/templates" ]]; then
    TEMPLATES_DIR="${SITE_DIR}/templates"
else
    TEMPLATES_DIR="${CURRENT_DIR}/templates"
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Generates <link> tags for CSS files located in common/css or assets
generate_css_links() {
    local css_html=""
    local css_dir="${TEMPLATES_DIR}/common/css"
    
    if [[ -d "$css_dir" ]]; then
        for css_file in "${css_dir}"/*.css; do
            [[ -f "$css_file" ]] || continue
            local filename
            filename=$(basename "$css_file")
            css_html+="    <link rel=\"stylesheet\" href=\"/assets/css/${filename}\" />\n"
        done
    else
        css_html="    <link rel=\"stylesheet\" href=\"/assets/css/style.css\" />"
    fi
    echo -e "$css_html"
}

# Copies shared static assets (CSS, images) to the site output directory
copy_assets() {
    echo "📂 Copying static assets to ${SITE_DIR}..."
    mkdir -p "${SITE_DIR}/assets/css" "${SITE_DIR}/assets/images"

    if [[ -d "${TEMPLATES_DIR}/common/css" ]]; then
        cp -r "${TEMPLATES_DIR}/common/css/"* "${SITE_DIR}/assets/css/" 2>/dev/null || true
    fi
    if [[ -d "${TEMPLATES_DIR}/common/images" ]]; then
        cp -r "${TEMPLATES_DIR}/common/images/"* "${SITE_DIR}/assets/images/" 2>/dev/null || true
    fi
}

# Dynamically finds the template file used for single blog posts
find_article_template() {
    local candidate
    local candidates=("article.html" "articles.html" "post.html" "single.html")
    
    for candidate in "${candidates[@]}"; do
        if [[ -f "${TEMPLATES_DIR}/${candidate}" ]]; then
            echo "${TEMPLATES_DIR}/${candidate}"
            return 0
        fi
    done

    # Fallback: Find any HTML file containing the {{BODY}} placeholder
    local body_match
    body_match=$(grep -rl "{{BODY}}" "$TEMPLATES_DIR" 2>/dev/null | head -n 1 || true)
    if [[ -n "$body_match" ]]; then
        echo "$body_match"
        return 0
    fi

    return 1
}

# ==============================================================================
# MAIN BUILD ENGINE
# ==============================================================================
build_site() {
    echo "🚀 Starting build process for site: '${SITE_NAME}'"
    echo "🎨 Active Template: '${SITE_TEMPLATE}' (${TEMPLATES_DIR})"

    if declare -f ensure_pandoc_installed >/dev/null; then
        ensure_pandoc_installed
    fi

    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        echo "❌ Error: Selected template directory '${TEMPLATES_DIR}' does not exist." >&2
        exit 1
    fi

    if [[ ! -d "$POSTS_DIR" ]]; then
        echo "❌ Error: Posts directory '${POSTS_DIR}' does not exist." >&2
        exit 1
    fi

    # 1. Prepare assets and CSS link tags
    copy_assets
    local css_links
    css_links=$(generate_css_links)

    # 2. Locate post/article template
    local article_template_path
    article_template_path=$(find_article_template || true)

    if [[ -z "$article_template_path" || ! -f "$article_template_path" ]]; then
        echo "❌ Error: Could not find an article template in ${TEMPLATES_DIR}" >&2
        exit 1
    fi

    local template_article
    template_article=$(cat "$article_template_path")
    local posts_list_html=""

    # 3. Process all Markdown post files
    echo "📝 Processing Markdown files..."
    
    shopt -s nullglob
    local md_files=("${POSTS_DIR}"/*.md)
    shopt -u nullglob

    if (( ${#md_files[@]} == 0 )); then
        echo "⚠️  No .md files found in ${POSTS_DIR}"
    fi

    for md_file in "${md_files[@]}"; do
        echo "   -> Compiling: $(basename "$md_file")"

        # Extract frontmatter metadata using markdown helper functions
        local title author date human_date description rel_path thumbnail
        title=$(extract_frontmatter_property "$md_file" "title")
        author=$(extract_frontmatter_property "$md_file" "author")
        date=$(extract_frontmatter_property "$md_file" "date")
        human_date=$(extract_frontmatter_property "$md_file" "human_date")
        description=$(extract_frontmatter_property "$md_file" "description")
        rel_path=$(extract_frontmatter_property "$md_file" "path")
        thumbnail=$(extract_frontmatter_property "$md_file" "thumbnail")

        # Set default values if frontmatter fields are missing
        [[ -z "$author" ]] && author="$SITE_AUTHOR"
        [[ -z "$human_date" ]] && human_date="$date"
        
        # Format HTML tags
        local tags_html=""
        if declare -f extract_frontmatter_tags >/dev/null; then
            while IFS= read -r tag; do
                [[ -n "$tag" ]] && tags_html+="<span class=\"tag\">#${tag}</span> "
            done < <(extract_frontmatter_tags "$md_file")
        fi

        # Convert Markdown body to HTML via Pandoc
        local post_body
        post_body=$(pandoc --from=markdown --to=html "$md_file")

        # Determine target output path (Clean URLs)
        local output_file
        local web_url

        if [[ -n "$rel_path" ]]; then
            local target_dir="${SITE_DIR}/${rel_path}"
            mkdir -p "$target_dir"
            output_file="${target_dir}/index.html"
            web_url="/${rel_path}/"
        else
            local base_name
            base_name=$(basename "$md_file" .md)
            local target_dir="${SITE_DIR}/posts/${base_name}"
            mkdir -p "$target_dir"
            output_file="${target_dir}/index.html"
            web_url="/posts/${base_name}/"
        fi

        # Substitute variables in article template
        local rendered_post="$template_article"
        rendered_post="${rendered_post//\{\{SITE_LANG\}\}/$SITE_LANG}"
        rendered_post="${rendered_post//\{\{SITE_TITLE\}\}/$SITE_TITLE}"
        rendered_post="${rendered_post//\{\{SITE_AUTHOR\}\}/$SITE_AUTHOR}"
        rendered_post="${rendered_post//\{\{SITE_TEMPLATE\}\}/$SITE_TEMPLATE}"
        rendered_post="${rendered_post//\{\{CSS_LINKS\}\}/$css_links}"
        rendered_post="${rendered_post//\{\{TITLE\}\}/$title}"
        rendered_post="${rendered_post//\{\{DESCRIPTION\}\}/$description}"
        rendered_post="${rendered_post//\{\{AUTHOR\}\}/$author}"
        rendered_post="${rendered_post//\{\{DATE\}\}/$human_date}"
        rendered_post="${rendered_post//\{\{TAGS\}\}/$tags_html}"
        rendered_post="${rendered_post//\{\{BODY\}\}/$post_body}"
        rendered_post="${rendered_post//\{\{TOC\}\}/}"

        # Write rendered post to output file
        echo "$rendered_post" > "$output_file"

        # Accumulate list item for index/archive templates
        posts_list_html+="          <li class=\"post-item\">\n"
        posts_list_html+="            <span class=\"post-date\">[${human_date}]</span>\n"
        posts_list_html+="            <a href=\"${web_url}\" class=\"post-link\">${title}</a>\n"
        posts_list_html+="          </li>\n"
    done

    # 4. Recursively process all HTML template files and mirror paths
    echo "📄 Processing HTML templates..."
    
    while IFS= read -r -d '' html_file; do
        # Determine path relative to TEMPLATES_DIR
        local rel_template_path="${html_file#"${TEMPLATES_DIR}/"}"

        # Skip the article layout template so it isn't rendered as a standalone empty page
        if [[ "$html_file" == "$article_template_path" ]]; then
            continue
        fi

        echo "   -> Rendering template: ${rel_template_path}"

        local template_content
        template_content=$(cat "$html_file")

        # Perform placeholder substitutions across every HTML template
        local rendered_html="$template_content"
        rendered_html="${rendered_html//\{\{SITE_LANG\}\}/$SITE_LANG}"
        rendered_html="${rendered_html//\{\{SITE_TITLE\}\}/$SITE_TITLE}"
        rendered_html="${rendered_html//\{\{SITE_AUTHOR\}\}/$SITE_AUTHOR}"
        rendered_html="${rendered_html//\{\{SITE_DESC\}\}/$SITE_DESC}"
        rendered_html="${rendered_html//\{\{SITE_TEMPLATE\}\}/$SITE_TEMPLATE}"
        rendered_html="${rendered_html//\{\{CSS_LINKS\}\}/$css_links}"
        rendered_html="${rendered_html//\{\{POSTS_LIST\}\}/$posts_list_html}"

        # Mirror file path structure to site output folder
        local target_output_file="${SITE_DIR}/${rel_template_path}"
        mkdir -p "$(dirname "$target_output_file")"
        echo -e "$rendered_html" > "$target_output_file"

    done < <(find "$TEMPLATES_DIR" -type f -name "*.html" -print0)

    echo "✅ Build completed successfully! Files are ready at: ${SITE_DIR}"
}

