#!/bin/zsh
# Converts compiled .scpt files into plain-text .applescript files so GitHub
# can display them and track changes line by line.
#
# Usage: tools/convert-scpt.sh path/to/script.scpt [more.scpt ...]
#        tools/convert-scpt.sh path/to/folder     (converts every .scpt inside)

set -e

convert() {
  local src="$1"
  local dest="${src%.scpt}.applescript"
  osadecompile "$src" > "$dest"
  echo "Converted: $src -> $dest"
}

for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    find "$arg" -name '*.scpt' -print0 | while IFS= read -r -d '' f; do convert "$f"; done
  else
    convert "$arg"
  fi
done
