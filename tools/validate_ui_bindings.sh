#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

check_scene() {
	local script_path="$1"
	local scene_path="${script_path%.gd}.tscn"
	while IFS= read -r node_name; do
		if ! awk -v node="$node_name" '
		BEGIN { found = 0; unique = 0 }
		/^\[node / {
			if (found) { exit }
			found = ($0 ~ "name=\"" node "\"" || $0 ~ "name = \"" node "\"")
		}
		found && /unique_name_in_owner = true/ { unique = 1 }
		END { if (!unique) exit 1 }
		' "$scene_path"; then
			echo "Missing unique binding: $scene_path -> %$node_name"
			status=1
		fi
	done < <(
		rg -o '@onready var [^=]+ = %[A-Za-z0-9_]+' "$script_path" \
			| sed -E 's/.*%//' \
			| sort -u
	)
}

cd "$project_root"
check_scene "scenes/main/main.gd"

if [[ "$status" -eq 0 ]]; then
	echo "UI binding validation passed."
fi
exit "$status"
