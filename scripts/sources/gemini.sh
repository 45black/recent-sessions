# Gemini CLI per-project history directory scanner.

scan_gemini() {
  local dir="${GEMINI_HISTORY_DIR:-$HOME/.gemini/history}"
  [[ -d "$dir" ]] || return 0
  local project latest mtime
  while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    latest=$(find "$dir/$project" -type f -print0 2>/dev/null \
      | xargs -0 stat -f '%m %N' 2>/dev/null \
      | sort -nr | head -1)
    [[ -n "$latest" ]] || continue
    mtime=${latest%% *}
    emit "$mtime" "gemini" "$project" "$project" "gemini (history dir: $project)"
  done < <(ls -1 "$dir" 2>/dev/null)
}
