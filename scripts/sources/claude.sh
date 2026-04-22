# Claude Code session-file scanner.
# Default root: ~/.claude/projects. Override via CLAUDE_PROJECTS_DIR in config.env.

scan_claude() {
  local dir="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' f; do
    local mtime session project
    mtime=$(file_mtime "$f")
    session=$(basename "$f" .jsonl)
    project=$(basename "$(dirname "$f")")
    emit "$mtime" "claude" "$project" "$session" "claude --resume $session"
  done < <(find "$dir" -maxdepth 3 -type f -name "*.jsonl" -print0 2>/dev/null)
}
