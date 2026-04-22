# Cursor workspaceStorage scanner. Also works for any VS Code fork: just point
# CURSOR_WORKSPACE_DIR at the right path.

scan_cursor() {
  local root="${CURSOR_WORKSPACE_DIR:-$HOME/Library/Application Support/Cursor/User/workspaceStorage}"
  _scan_vscode_like cursor "$root" "cursor"
}
