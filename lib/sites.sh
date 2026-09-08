#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155,SC2154

get_all_sites() {
    if [[ -d "$SITES_DIR" ]]; then
        for dir in "${SITES_DIR}"/*/; do
            [[ -d "$dir" ]] || continue
            basename "$dir"
        done
    fi
}

build_all_sites() {
    print_section "Building ALL Sites"
    local sites
    readarray -t sites < <(get_all_sites)

    if [[ ${#sites[@]} -eq 0 ]]; then
        msg_warn "No sites found in workspace."
        return 0
    fi

    for site_slug in "${sites[@]}"; do
        build_site "$site_slug"
    done

    update_sites_index
}

update_sites_index() {
    local index_file="${SITES_DIR}/index.html"

    ensure_dir "$SITES_DIR"
    msg_build "Updating main sites Dashboard at: sites/index.html"

    local cards_html=""
    local site_count=0

    for dir in "${SITES_DIR}"/*/; do
        [[ -d "$dir" ]] || continue

        local slug
        slug=$(basename "$dir")
        
        # Búsqueda de configuración unificada
        local config_path="${dir}config.yaml"
        [[ ! -f "$config_path" && -f "${dir}config.yml" ]] && config_path="${dir}config.yml"

        local title description author lang
        title=$(get_site_yaml_prop "$config_path" "site" "title" "$slug")
        description=$(get_site_yaml_prop "$config_path" "site" "description" "No description available.")
        author=$(get_site_yaml_prop "$config_path" "site" "author" "Unknown")
        lang=$(get_site_yaml_prop "$config_path" "site" "language" "es")

        ((site_count++)) || true

        cards_html+="
        <a href=\"/${slug}/\" class=\"card\">
          <div class=\"card-header\">
            <h3>${title}</h3>
            <span class=\"badge\">${lang}</span>
          </div>
          <p class=\"description\">${description}</p>
          <div class=\"card-footer\">
            <span class=\"author\">👤 ${author}</span>
            <span class=\"link-text\">Visit &rarr;</span>
          </div>
        </a>"
    done

    cat <<EOF > "$index_file"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zeta — Local Dashboard</title>
  <style>
    :root {
      --bg: #0d1117; --card-bg: #161b22; --border: #30363d;
      --border-hover: #58a6ff; --text: #c9d1d9; --text-muted: #8b949e;
      --title: #f0f6fc; --accent: #58a6ff;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; background-color: var(--bg); color: var(--text); padding: 2rem 1rem; }
    header { max-width: 1000px; margin: 0 auto 3rem; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); padding-bottom: 1.5rem; }
    .brand { display: flex; align-items: center; gap: 0.75rem; }
    .brand-logo { background: linear-gradient(135deg, #38ef7d, #11998e); color: #000; font-weight: 800; padding: 0.4rem 0.8rem; border-radius: 6px; }
    .counter { background: var(--card-bg); border: 1px solid var(--border); color: var(--text-muted); padding: 0.3rem 0.75rem; border-radius: 20px; font-size: 0.85rem; }
    main { max-width: 1000px; margin: 0 auto; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1.5rem; }
    .card { background-color: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; text-decoration: none; color: inherit; display: flex; flex-direction: column; justify-content: space-between; }
    .card:hover { border-color: var(--border-hover); transform: translateY(-3px); }
    .card-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem; }
    .badge { background: var(--border); color: var(--text); font-size: 0.7rem; text-transform: uppercase; padding: 0.15rem 0.4rem; border-radius: 4px; }
    .description { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
    .card-footer { display: flex; justify-content: space-between; font-size: 0.8rem; color: var(--text-muted); border-top: 1px solid rgba(255, 255, 255, 0.05); padding-top: 0.75rem; }
    .link-text { color: var(--accent); font-weight: 600; }
  </style>
</head>
<body>
  <header>
    <div class="brand"><div class="brand-logo">Z</div><h1>Zeta Sites</h1></div>
    <div class="counter">${site_count} hosted site(s)</div>
  </header>
  <main>
    $([[ "$site_count" -gt 0 ]] && echo "<div class=\"grid\">${cards_html}</div>" || echo "<p>No sites found.</p>")
  </main>
</body>
</html>
EOF

    msg_success "Dashboard 'sites/index.html' updated successfully."
}

create_new_site() {
    print_section "Create New Site"

    read -rp "$(echo -e "${boldCyan}▶ Site title${endColour} [My New Blog]: ")" site_title
    site_title="${site_title:-My New Blog}"

    read -rp "$(echo -e "${boldCyan}▶ Description${endColour} [Blog generado con Zeta]: ")" site_desc
    site_desc="${site_desc:-Blog generado con Zeta}"

    read -rp "$(echo -e "${boldCyan}▶ Author${endColour} [${USER:-User}]: ")" site_author
    site_author="${site_author:-${USER:-User}}"

    read -rp "$(echo -e "${boldCyan}▶ Language${endColour} [es]: ")" site_lang
    site_lang="${site_lang:-es}"

    local default_slug
    if command_exists slugify; then
        default_slug=$(slugify "$site_title")
    else
        default_slug=$(echo "$site_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')
    fi

    read -rp "$(echo -e "${boldCyan}▶ Folder name (slug)${endColour} [${default_slug}]: ")" site_slug
    site_slug="${site_slug:-$default_slug}"

    local site_path="${SITES_DIR}/${site_slug}"

    if [[ -d "$site_path" ]]; then
        msg_error "Directory '${site_path}' already exists."
        return 1
    fi

    local available_templates=()
    
    if [[ -d "$TEMPLATES_DIR" ]]; then
        for t_dir in "${TEMPLATES_DIR}"/*/; do
            [[ -d "$t_dir" ]] || continue
            local t_name
            t_name=$(basename "$t_dir")

            case "$t_name" in
                common|styles|css|js|assets|vendor|includes|layouts|\.*)
                    continue
                    ;;
            esac

            available_templates+=("$t_name")
        done
    fi

    local selected_theme="zen"

    if [[ ${#available_templates[@]} -gt 0 ]]; then
        echo -e "\n${boldYellow}Select Site Template:${endColour}"
        local t_idx=1
        
        for t in "${available_templates[@]}"; do
            echo -e "  [${t_idx}] ${t}"
            ((t_idx++))
        done

        read -rp "$(echo -e "${boldCyan}▶ Select option [1 - ${#available_templates[@]}]: ${endColour}")" t_choice
        if [[ "$t_choice" =~ ^[0-9]+$ ]] && (( t_choice >= 1 && t_choice <= ${#available_templates[@]} )); then
            selected_theme="${available_templates[$((t_choice - 1))]}"
        else
            msg_warn "Invalid option. Falling back to '${selected_theme}'."
        fi
    else
        msg_warn "No templates found in '${TEMPLATES_DIR}'. Defaulting theme to '${selected_theme}'."
    fi

    local available_pandoc_themes=()
    if command_exists pandoc; then
        readarray -t available_pandoc_themes < <(pandoc --list-highlight-styles 2>/dev/null || pandoc --list-highlight-languages 2>/dev/null)
    fi

    if [[ ${#available_pandoc_themes[@]} -eq 0 ]]; then
        available_pandoc_themes=("zenburn" "pygments" "kate" "monokai" "breezeDark" "tango" "espresso")
    fi

    local selected_pandoc_theme="zenburn"
    echo -e "\n${boldYellow}Select Pandoc Syntax Highlighting Theme:${endColour}"
    local p_idx=1
    local default_p_idx=1

    for p in "${available_pandoc_themes[@]}"; do
        if [[ "$p" == "zenburn" ]]; then
            default_p_idx=$p_idx
            echo -e "  [${p_idx}] ${p} ${grayColour}(default)${endColour}"
        else
            echo -e "  [${p_idx}] ${p}"
        fi
        ((p_idx++))
    done

    read -rp "$(echo -e "${boldCyan}▶ Select option [default ${default_p_idx}]: ${endColour}")" p_choice
    if [[ -z "$p_choice" ]]; then
        selected_pandoc_theme="zenburn"
    elif [[ "$p_choice" =~ ^[0-9]+$ ]] && (( p_choice >= 1 && p_choice <= ${#available_pandoc_themes[@]} )); then
        selected_pandoc_theme="${available_pandoc_themes[$((p_choice - 1))]}"
    else
        msg_warn "Invalid option. Falling back to '${selected_pandoc_theme}'."
    fi

    ensure_dir "$site_path/posts"

    if [[ -d "${TEMPLATES_DIR}/${selected_theme}" ]]; then
        cp -r "${TEMPLATES_DIR}/${selected_theme}/"* "$site_path/" 2>/dev/null || true
    fi

    local template_config="${TEMPLATES_DIR}/config.yaml"
    [[ ! -f "$template_config" && -f "${TEMPLATES_DIR}/config.yml" ]] && template_config="${TEMPLATES_DIR}/config.yml"
    
    local target_config="${site_path}/config.yaml"

    if [[ -f "$template_config" ]]; then
        cp "$template_config" "$target_config"
    else
        msg_error "Base configuration template not found at: ${template_config}"
        return 1
    fi

    local tmp_config="${target_config}.tmp"
    sed \
        -e "s|title: \".*\"|title: \"${site_title}\"|" \
        -e "s|description: \".*\"|description: \"${site_desc}\"|" \
        -e "s|author: \".*\"|author: \"${site_author}\"|" \
        -e "s|language: \".*\"|language: \"${site_lang}\"|" \
        -e "s|name: \".*\"|name: \"${selected_theme}\"|" \
        -e "s|pandoc_theme: \".*\"|pandoc_theme: \"${selected_pandoc_theme}\"|" \
        "$target_config" > "$tmp_config" && mv "$tmp_config" "$target_config"

    update_sites_index
    msg_success "Site '${site_title}' created successfully at: ${site_path}"
}