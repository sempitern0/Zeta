#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155

extract_frontmatter_property() {
    local markdown_file="$1"
    local property="$2"
    local line_num=0
    local in_frontmatter=0
    local line value
    local pattern="^[[:space:]]*${property}[[:space:]]*:[[:space:]]*(.*)$"

    if [[ ! -f "$markdown_file" ]]; then
        echo ""
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line="${line%$'\r'}"

        if (( line_num == 1 )); then
            if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
                in_frontmatter=1
                continue
            else
                echo ""
                return 1
            fi
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            break
        fi

        if (( in_frontmatter == 1 )); then
            if [[ "$line" =~ $pattern ]]; then
                value="${BASH_REMATCH[1]}"
                
                # Eliminar comillas envolventes
                value="${value#\"}"
                value="${value%\"}"
                value="${value#\'}"
                value="${value%\'}"
                
                # Limpiar espacios finales
                while [[ "$value" == *[[:space:]] ]]; do
                    value="${value%[[:space:]]}"
                done
                
                echo "$value"
                return 0
            fi
        fi

    done < "$markdown_file"

    echo ""
    return 0
}


extract_frontmatter_tags() {
    local markdown_file="$1"
    [[ ! -f "$markdown_file" ]] && return 0

    local in_frontmatter=0
    local in_tags=0
    local line_num=0
    local -a tags_array=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line="${line%$'\r'}"

        if (( line_num == 1 )); then
            if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
                in_frontmatter=1
                continue
            else
                return 0
            fi
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            break
        fi

        if (( in_frontmatter == 1 )); then
            # Caso A: Formato en línea (tags: [linux, bash] o tags: "linux, bash")
            if [[ "$line" =~ ^[[:space:]]*tags[[:space:]]*:[[:space:]]*(.*)$ ]]; then
                local raw_val="${BASH_REMATCH[1]}"
                raw_val=$(echo "$raw_val" | xargs)

                if [[ -n "$raw_val" ]]; then
                    raw_val=$(echo "$raw_val" | tr -d '[]"')
                    raw_val=$(echo "$raw_val" | tr -d "'")

                    IFS=',' read -r -a items <<< "$raw_val"
                    for item in "${items[@]}"; do
                        item=$(echo "$item" | xargs)
                        [[ -n "$item" ]] && tags_array+=("$item")
                    done
                    break
                else
                    in_tags=1
                    continue
                fi
            fi

            if (( in_tags == 1 )); then
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
                    local tag_item="${BASH_REMATCH[1]}"
                    tag_item=$(echo "$tag_item" | tr -d '"' | tr -d "'" | xargs)
                    [[ -n "$tag_item" ]] && tags_array+=("$tag_item")
                elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_]+[[:space:]]*: ]]; then
                    in_tags=0
                fi
            fi
        fi
    done < "$markdown_file"

    local joined=""
    for tag in "${tags_array[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$tag"
        else
            joined="${joined}, ${tag}"
        fi
    done

    echo "$joined"
}