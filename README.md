# recent-sessions

A [Claude Code](https://claude.ai/code) skill that surfaces recently-active coding sessions across every agent and IDE on your machine — Claude Code itself, Codex CLI, Gemini CLI, Cursor, VS Code, git repos on mounted volumes, and Anthropic's Managed Agents cloud — so you can pick up where you left off without hunting through history.

## What it does

Given any question like "what was I working on yesterday?" or "show recent sessions", it produces an aligned, time-sorted table:

```
WHEN (UTC)            SOURCE     PROJECT                           IDENTIFIER                            RESUME HINT
2026-04-22T11:21:39Z  claude     -Volumes-Dev-projects             65e9536f-c232-4434-a127-62fef706cb99  claude --resume 65e9536f-...
2026-04-22T09:51:35Z  gemini     dev                               dev                                   gemini (history dir: dev)
2026-04-20T20:27:37Z  cursor     /Volumes/Dev/project-a            7ba8aa826d1b62498c186a2bafd42d44      cursor "/Volumes/Dev/project-a"
2026-04-10T09:45:38Z  codex      sessions                          rollout-2026-04-10T10-25-59-019d...   codex (rollout id ...)
```

Output is also available as JSON Lines for piping (`--json`).

## Sources

| Source     | Location                                                            | Identifier     |
|------------|---------------------------------------------------------------------|----------------|
| claude     | `~/.claude/projects/<project>/*.jsonl`                              | session UUID   |
| codex      | `~/.codex/{sessions,archived_sessions}/rollout-*.jsonl`             | rollout ID     |
| gemini     | `~/.gemini/history/<project>/`                                      | project name   |
| cursor     | `~/Library/Application Support/Cursor/User/workspaceStorage/*/`     | workspace hash |
| vscode    | `~/Library/Application Support/Code/User/workspaceStorage/*/`       | workspace hash |
| volumes    | `/Volumes/*/**/.git` (opt-in, scans mounted drives for active repos) | repo path      |
| anthropic  | `GET https://api.anthropic.com/v1/sessions` (Managed Agents beta)   | session ID     |

All local sources use file mtime as "last active". Cursor and VS Code workspace hashes are resolved back to folder paths by reading `workspace.json` inside each workspace directory.

## Install

Clone into your user-level skills directory:

```bash
git clone https://github.com/<owner>/recent-sessions.git ~/.claude/skills/recent-sessions
```

Or symlink from an existing checkout:

```bash
ln -s /path/to/recent-sessions ~/.claude/skills/recent-sessions
```

Claude Code auto-discovers skills under `~/.claude/skills/`. Restart Claude Code (or `/clear`) and ask for "recent sessions" to invoke it.

## First-run setup

Before anything runs, decide which sources to enable:

```bash
bash ~/.claude/skills/recent-sessions/scripts/setup.sh
```

The setup walks you through:

1. Probes every source and reports what was found on this machine.
2. Asks per-source enable toggles (defaults pre-populated).
3. If the Anthropic source is enabled, asks how to supply the API key:
   - **Doppler** — fetch once, cache to `~/.claude/secrets/recent-sessions-anthropic.env` (0600).
   - **Env file** — point at a path you already maintain.
   - **Shell** — nothing written; you export `$ANTHROPIC_API_KEY` yourself.

Output: `config.env` in the skill root. It's plain shell — hand-edit freely, or re-run `setup.sh` to regenerate.

## Running

```bash
# Honour config.env toggles
bash ~/.claude/skills/recent-sessions/scripts/list-recent-sessions.sh --hours 168 --limit 20

# Restrict to one source, ignoring config
bash ~/.claude/skills/recent-sessions/scripts/list-recent-sessions.sh --source cursor --hours 72

# Multiple sources in one run
bash ~/.claude/skills/recent-sessions/scripts/list-recent-sessions.sh --source claude --source anthropic

# JSON Lines for piping
bash ~/.claude/skills/recent-sessions/scripts/list-recent-sessions.sh --json | jq -c

# Re-run interactive setup
bash ~/.claude/skills/recent-sessions/scripts/list-recent-sessions.sh --setup
```

Flags:

- `--hours N` — window (default 72)
- `--limit N` — max rows (default 30)
- `--source NAME` — restrict to one source; repeat for multiple. Overrides `config.env`.
- `--json` — JSON Lines rather than the default aligned table
- `--setup` — re-enter the interactive configurator and exit

## Anthropic Managed Agents — notes

The `anthropic` source needs a standard `sk-ant-api-*` inference key on an account with the Managed Agents beta enabled on the Anthropic Console. **`sk-ant-admin-*` admin keys won't work** — those are scoped to `/v1/organizations/*` endpoints only.

The beta header label (`ANTHROPIC_BETA_HEADER`) drifts periodically. If you get `HTTP 400` with a message telling you the current label, update it in `config.env`. As of 2026-04-22 the working values are:

- `/v1/sessions`, `/v1/vaults` — `managed-agents-2026-04-01`
- `/v1/agents` — `agent-api-2026-03-01`

The scanner reads response fields defensively (`.sessions // .data`, `.id // .session_id`, `.updated_at // .last_used_at // .created_at`) so minor response-shape drift between beta revisions won't break it.

## Architecture

Modular per-source design — one file per source under `scripts/sources/` emitting TSV rows via a shared `emit()` helper in `_common.sh`. The dispatcher sorts, limits, and formats output. Adding a new source:

1. Create `scripts/sources/<name>.sh` with a `scan_<name>()` function that calls `emit`.
2. Register `load_source <name> SOURCE_<NAME>` in `list-recent-sessions.sh`.
3. Add `SOURCE_<NAME>` toggle to `config.env`.

Helpers like `_scan_vscode_like` (used by both `cursor.sh` and `vscode.sh`) live in `_common.sh` so source files can be loaded in any order without depending on each other.

## Layout

```
recent-sessions/
├── README.md
├── LICENSE
├── SKILL.md                          # skill definition + architecture notes
├── .gitignore
└── scripts/
    ├── list-recent-sessions.sh       # dispatcher
    ├── setup.sh                      # interactive configurator
    └── sources/
        ├── _common.sh                # emit, file_mtime, iso_to_epoch, _scan_vscode_like
        ├── claude.sh
        ├── codex.sh
        ├── gemini.sh
        ├── cursor.sh
        ├── vscode.sh
        ├── volumes.sh
        └── anthropic.sh              # Managed Agents cloud
```

## License

MIT — see [LICENSE](LICENSE).
