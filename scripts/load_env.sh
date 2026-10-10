#!/usr/bin/env bash

# Lee asignaciones sencillas KEY=VALUE sin evaluar el contenido como código.
# Variables que ya vienen del entorno (por ejemplo, GitHub Actions) prevalecen.
load_env_file() {
    local file="${1:-.env}"
    local line key value

    [[ -f "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line#$'\xEF\xBB\xBF'}"
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            echo "ERROR: nombre de variable inválido en $file." >&2
            return 1
        fi

        if [[ "$value" == \"*\" ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' ]]; then
            value="${value:1:${#value}-2}"
        fi

        if [[ -z "${!key:-}" ]]; then
            export "$key=$value"
        fi
    done < "$file"
}
