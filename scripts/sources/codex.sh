# Codex CLI rollout-*.jsonl scanner. Covers both live and archived sessions.

scan_codex() {
  local live_dir="${CODEX_SESSION_DIR:-$HOME/.codex/sessions}"
  local archive_dir="${CODEX_ARCHIVE_DIR:-$HOME/.codex/archived_sessions}"
  local dir
  for dir in "$live_dir" "$archive_dir"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
      local mtime id subdir
      mtime=$(file_mtime "$f")
      id=$(basename "$f" .jsonl)
      subdir=$(basename "$dir")
      emit "$mtime" "codex" "$subdir" "$id" "codex (rollout $id)"
    done < <(find "$dir" -type f -name "rollout-*.jsonl" -print0 2>/dev/null)
  done
}
