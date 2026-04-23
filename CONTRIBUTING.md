# Contributing

Thanks for considering a contribution. The skill is deliberately small and
modular — adding a new source typically means touching three places.

## Adding a new source

Each source lives in its own file under `scripts/sources/`, exposes one
function `scan_<name>()`, and emits TSV rows through the shared `emit` helper.

### 1. Write the scanner

Create `scripts/sources/<name>.sh`:

```bash
# Short description of what this source tracks and where it lives.

scan_<name>() {
  local dir="${<NAME>_DIR:-$HOME/some/default/path}"
  [[ -d "$dir" ]] || return 0

  # Walk the source and emit one row per "session". mtime is the
  # canonical "last active" signal; identifier is whatever the tool
  # uses to resume the session; hint is a copy-pasteable command.
  while IFS= read -r -d '' file; do
    local mtime id project
    mtime=$(file_mtime "$file")
    id=$(basename "$file" .ext)
    project=$(basename "$(dirname "$file")")
    emit "$mtime" "<name>" "$project" "$id" "<tool> --resume $id"
  done < <(find "$dir" -type f -name '*.ext' -print0 2>/dev/null)
}
```

`emit` signature: `emit <mtime_epoch> <source> <project> <identifier> <hint>`.
It silently drops rows outside the `--hours` window, so scanners don't
need to filter by age themselves.

For cloud sources, use `curl` + `jq` and read defensively (`.sessions //
.data`, `.id // .session_id`) so API-shape drift doesn't break the
scanner. See `scripts/sources/anthropic.sh` for the pattern — it handles
stale beta headers, empty inventories, and network failures gracefully,
each of which is a one-line stderr diagnostic rather than a hard failure.

### 2. Register the source in the dispatcher

Edit `scripts/list-recent-sessions.sh`:

- Add `SOURCE_<NAME>=0` to the defaults block (or `=1` if it's a local
  source that should be on by default).
- Add a case arm under the `--source` CLI handler.
- Add one `load_source <name> SOURCE_<NAME>` line in the dispatch block.

### 3. Expose the toggle in setup

Edit `scripts/setup.sh`:

- Add a `probe "<name>" "$HOME/..."` line in the probe block.
- Add one `enable_<name>=$(yesno "Enable <name>" "y|n")` line.
- Emit `SOURCE_<NAME>=$enable_<name>` when writing `config.env`.

If the source needs credentials, follow the Anthropic auth pattern:
offer Doppler (cached to `~/.claude/secrets/recent-sessions-<name>.env`
at 0600), a user-maintained env file, or a shell env var.

## Style

- UK English in prose, conventional-commit-style subjects in commits.
- Bash 3.2-compatible (macOS ships old bash; don't rely on associative
  arrays, `wait -n`, or `readarray` without a fallback).
- No external runtime dependencies beyond `bash`, `find`, `stat`, `jq`,
  and `curl`. All should be standard on macOS and most Linux distros.
- Defensive reads (`// empty` in jq, `|| true` after optional steps).
- Short one-line comments explaining **why**, not what.

## Testing

There's no test harness yet — contributions that add one are welcome.
Minimum pre-PR check:

```bash
bash -n scripts/list-recent-sessions.sh scripts/setup.sh scripts/sources/*.sh
bash scripts/list-recent-sessions.sh --hours 168 --limit 5
bash scripts/list-recent-sessions.sh --hours 24 --json | jq -c .
```

For a new source, also:

```bash
bash scripts/list-recent-sessions.sh --source <name>
```

Should return either a table, an empty result ("No sessions in the
last 72h." on stderr), or a one-line diagnostic when the source is
unreachable. It should never crash or leak partial output.

## Scope boundaries

In scope:
- New local IDE / agent session stores.
- New cloud APIs that let the user list their own recent sessions.
- Improvements to resume-hint formatting or sort order.

Out of scope:
- Long-running daemons, caching layers, or persistent state.
- Features that require background processes or cron jobs.
- Anything that writes outside `~/.claude/skills/recent-sessions/` or
  `~/.claude/secrets/`.

Keep the scanner stateless; the skill is meant to be cheap to invoke
and safe to run at any time.
