#!/usr/bin/env bash
# lib/sites.sh - Gestión global de sitios workspace
# shellcheck disable=SC2034,SC2155,SC2154

# Lista los slugs de todos los sitios existentes
get_all_sites() {
    local sites_dir="${SITES_DIR:-${CURRENT_DIR}/sites}"
    if [[ -d "$sites_dir" ]]; then
        for dir in "${sites_dir}"/*/; do
            [[ -d "$dir" ]] || continue
            basename "$dir"
        done
    fi
}

# Compila todos los sitios secuencialmente
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

# Regenera el archivo sites/index.html
update_sites_index() {
    local sites_dir="${SITES_DIR:-${CURRENT_DIR}/sites}"
    local index_file="${sites_dir}/index.html"

    ensure_dir "$sites_dir"
    msg_build "Updating main sites Dashboard at: sites/index.html"

    local cards_html=""
    local site_count=0

    for dir in "${sites_dir}"/*/; do
        [[ -d "$dir" ]] || continue

        local slug
        slug=$(basename "$dir")
        local config_path="${dir}config.yml"

        # Leer datos con fallback
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

# Asistente interactivo para crear un sitio
create_new_site() {
    print_section "Create New Site"

    read -rp "$(echo -e "${boldCyan}▶ Site title${endColour} [My New Blog]: ")" site_title
    site_title="${site_title:-My New Blog}"

    read -rp "$(echo -e "${boldCyan}▶ Description${endColour} [Blog generado con Zeta]: ")" site_desc
    site_desc="${site_desc:-Blog generado con Zeta}"

    read -rp "$(echo -e "${boldCyan}▶ Author${endColour} [User]: ")" site_author
    site_author="${site_author:-User}"

    read -rp "$(echo -e "${boldCyan}▶ Language${endColour} [es]: ")" site_lang
    site_lang="${site_lang:-es}"

    local default_slug
    default_slug=$(echo "$site_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    read -rp "$(echo -e "${boldCyan}▶ Folder name (slug)${endColour} [${default_slug}]: ")" site_slug
    site_slug="${site_slug:-$default_slug}"

    local site_path="${SITES_DIR}/${site_slug}"
    ensure_dir "$site_path/posts"

    # Escribir estructura YAML con secciones
    cat <<EOF > "${site_path}/config.yml"
site:
  title: "${site_title}"
  description: "${site_desc}"
  author: "${site_author}"
  language: "${site_lang}"

theme:
  name: "basic"

build:
  content_dir: "posts"
  output_dir: "public"
EOF

    update_sites_index
    msg_success "Site '${site_title}' created at: ${site_path}"
}