# Shared helpers for every source. Sourced — not executed.
# Expects CUTOFF_EPOCH and TMP to exist in the caller's scope.

emit() {
  # $1=mtime_epoch $2=source $3=project $4=identifier $5=hint
  local mtime="$1" source="$2" project="$3" ident="$4" hint="${5:-}"
  [[ "$mtime" =~ ^[0-9]+$ ]] || return 0
  [[ "$mtime" -ge "$CUTOFF_EPOCH" ]] || return 0
  local iso
  iso=$(date -r "$mtime" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mtime" "$iso" "$source" "$project" "$ident" "$hint" >> "$TMP"
}

file_mtime() {
  stat -f%m "$1" 2>/dev/null || stat --format=%Y "$1" 2>/dev/null || echo 0
}

iso_to_epoch() {
  local iso="$1"
  # Tolerate 2026-04-21T12:34:56Z or with fractional seconds
  iso="${iso%%.*}"
  iso="${iso%Z}"
  date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null \
    || date -u -d "$iso" +%s 2>/dev/null \
    || echo 0
}

# Shared VS Code-family workspaceStorage scanner — used by cursor.sh and
# vscode.sh. Lives in _common.sh so source files can be loaded in any order.
_scan_vscode_like() {
  local label="$1" root="$2" open_cmd="$3"
  [[ -d "$root" ]] || return 0
  local ws hash mtime folder project ident hint
  for ws in "$root"/*/; do
    [[ -d "$ws" ]] || continue
    hash=$(basename "$ws")
    mtime=$(file_mtime "$ws")
    folder=""
    if [[ -f "${ws}workspace.json" ]] && command -v jq &>/dev/null; then
      folder=$(jq -r '.folder // .workspace // empty' "${ws}workspace.json" 2>/dev/null | sed 's#^file://##')
    fi
    if [[ -n "$folder" ]]; then
      project="$folder"
      ident="$hash"
      hint="$open_cmd \"$folder\""
    else
      project="(unresolved)"
      ident="$hash"
      hint="workspace hash only — inspect ${ws}workspace.json"
    fi
    emit "$mtime" "$label" "$project" "$ident" "$hint"
  done
}
