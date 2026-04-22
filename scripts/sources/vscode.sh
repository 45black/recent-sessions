# VS Code workspaceStorage scanner. Shares _scan_vscode_like with Cursor.

scan_vscode() {
  local root="${VSCODE_WORKSPACE_DIR:-$HOME/Library/Application Support/Code/User/workspaceStorage}"
  _scan_vscode_like vscode "$root" "code"
}
