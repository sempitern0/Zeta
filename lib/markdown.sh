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
    local raw_tags

    raw_tags=$(extract_frontmatter_property "$markdown_file" "tags")

    # 1. Formato inline: tags: [bash, linux] o tags: bash, linux
    if [[ -n "$raw_tags" ]]; then
        local cleaned
        cleaned=$(echo "$raw_tags" | tr -d '[]"' | tr -d "'")

        local -a items
        IFS=',' read -r -a items <<< "$cleaned"
        for item in "${items[@]}"; do
            item=$(echo "$item" | xargs)
            [[ -n "$item" ]] && echo "$item"
        done
        return 0
    fi

    # 2. Formato multilínea YAML:
    # tags:
    #   - bash
    #   - linux
    local line_num=0
    local in_frontmatter=0
    local in_tags=0
    local line

    [[ ! -f "$markdown_file" ]] && return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line="${line%$'\r'}"

        if (( line_num == 1 )); then
            [[ "$line" =~ ^---[[:space:]]*$ ]] && in_frontmatter=1 && continue || return 0
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            break
        fi

        if (( in_frontmatter == 1 )); then
            if [[ "$line" =~ ^[[:space:]]*tags[[:space:]]*:[[:space:]]*$ ]]; then
                in_tags=1
                continue
            fi

            if (( in_tags == 1 )); then
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
                    local tag_item="${BASH_REMATCH[1]}"
                    tag_item=$(echo "$tag_item" | tr -d '"' | tr -d "'" | xargs)
                    [[ -n "$tag_item" ]] && echo "$tag_item"
                elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_]+[[:space:]]*: ]]; then
                    in_tags=0
                fi
            fi
        fi
    done < "$markdown_file"
}