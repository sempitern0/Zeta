#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155

trim_yaml_value() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

decode_yaml_scalar() {
    local value
    value=$(trim_yaml_value "$1")

    if [[ ${#value} -ge 2 && "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
        value="${value:1:${#value}-2}"
        value="${value//\\\"/\"}"
        value="${value//\\\\/\\}"
    elif [[ ${#value} -ge 2 && "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
        value="${value:1:${#value}-2}"
        value=$(printf '%s' "$value" | sed "s/''/'/g")
    fi

    printf '%s' "$value"
}

extract_frontmatter_property() {
    local markdown_file="$1"
    local property="$2"
    local line line_num=0 in_frontmatter=0
    local pattern="^[[:space:]]*${property}[[:space:]]*:[[:space:]]*(.*)$"

    [[ -f "$markdown_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++)) || true
        line="${line%$'\r'}"

        if (( line_num == 1 )); then
            [[ "$line" =~ ^---[[:space:]]*$ ]] || return 1
            in_frontmatter=1
            continue
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            break
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ $pattern ]]; then
            decode_yaml_scalar "${BASH_REMATCH[1]}"
            printf '\n'
            return 0
        fi
    done < "$markdown_file"

    printf '\n'
    return 0
}

extract_frontmatter_tags() {
    local markdown_file="$1"
    [[ -f "$markdown_file" ]] || return 0

    local line line_num=0 in_frontmatter=0 in_tags=0
    local -a tags_array=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++)) || true
        line="${line%$'\r'}"

        if (( line_num == 1 )); then
            [[ "$line" =~ ^---[[:space:]]*$ ]] || return 0
            in_frontmatter=1
            continue
        fi

        if (( in_frontmatter == 1 )) && [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            break
        fi

        if (( in_frontmatter == 0 )); then
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*tags[[:space:]]*:[[:space:]]*(.*)$ ]]; then
            local raw_val
            raw_val=$(trim_yaml_value "${BASH_REMATCH[1]}")

            if [[ -n "$raw_val" ]]; then
                [[ "$raw_val" == \[*\] ]] && raw_val="${raw_val:1:${#raw_val}-2}"
                local -a items=()
                local item
                IFS=',' read -r -a items <<< "$raw_val"
                for item in "${items[@]}"; do
                    item=$(decode_yaml_scalar "$item")
                    [[ -n "$item" ]] && tags_array+=("$item")
                done
                break
            fi

            in_tags=1
            continue
        fi

        if (( in_tags == 1 )); then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
                local tag_item
                tag_item=$(decode_yaml_scalar "${BASH_REMATCH[1]}")
                [[ -n "$tag_item" ]] && tags_array+=("$tag_item")
            elif [[ "$line" =~ ^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*: ]]; then
                in_tags=0
            fi
        fi
    done < "$markdown_file"

    local joined="" tag
    for tag in "${tags_array[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$tag"
        else
            joined+=", ${tag}"
        fi
    done

    printf '%s\n' "$joined"
}
