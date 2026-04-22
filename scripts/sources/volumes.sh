# Mounted-volume git-repo scanner. Opt-in because it walks /Volumes/*.
# Configure the list with VOLUMES_ROOTS="/Volumes/Dev /Volumes/ForgeRuntime".

scan_volumes() {
  local roots_raw="${VOLUMES_ROOTS:-}"
  local -a roots=()
  if [[ -n "$roots_raw" ]]; then
    read -r -a roots <<<"$roots_raw"
  else
    local v
    for v in /Volumes/*; do
      [[ -d "$v" ]] || continue
      [[ "$(basename "$v")" == "Macintosh HD" ]] && continue
      roots+=("$v")
    done
  fi

  local vol repo top mtime head_mtime index_mtime
  for vol in "${roots[@]}"; do
    [[ -d "$vol" ]] || continue
    while IFS= read -r -d '' repo; do
      top=$(dirname "$repo")
      head_mtime=0
      index_mtime=0
      [[ -f "$repo/HEAD"  ]] && head_mtime=$(file_mtime "$repo/HEAD")
      [[ -f "$repo/index" ]] && index_mtime=$(file_mtime "$repo/index")
      mtime=$head_mtime
      [[ "$index_mtime" -gt "$mtime" ]] && mtime=$index_mtime
      emit "$mtime" "volumes" "$top" "$top" "cd \"$top\" && git status"
    done < <(find "$vol" -type d -name ".git" -not -path "*/node_modules/*" -print0 2>/dev/null)
  done
}
