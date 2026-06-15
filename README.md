# codex-pulse

A tiny Codex CLI companion that adds a polished footer line and desktop friendly turn notifications.

## Install

```sh
curl -fsSL <RAW_URL>/install.sh | sh
```

The installer copies the scripts to `~/.codex/codex-pulse`, enables Codex hooks in `~/.codex/config.toml`, merges notification hooks into `~/.codex/hooks.json`, and prints the status line config to add when your Codex build supports it.

Manual install:

```sh
mkdir -p ~/.codex/codex-pulse
cp statusline.sh ~/.codex/codex-pulse/statusline.sh
cp hooks/notify.sh ~/.codex/codex-pulse/notify.sh
chmod +x ~/.codex/codex-pulse/statusline.sh ~/.codex/codex-pulse/notify.sh
```

Then copy the relevant examples from `examples/config-snippet.toml` and `examples/hooks.json`.

## What This Is

`statusline.sh` reads the JSON payload Codex sends to an external status command and prints one styled line for the TUI footer. It shows the model, project, git branch, dirty state, and context usage when those values are available.

`hooks/notify.sh` reads Codex hook JSON and sends a quick alert when a turn finishes or Codex needs attention.

What it needs:

- The status line requires a Codex build with the external command status line option.
- The notification hook works today wherever Codex hooks are enabled with `[features] codex_hooks = true`.
- Hooks are not supported on Windows.

## Configuration

Environment variables:

- `USE_NERD_FONTS`: defaults to `true`. Set to `false` to remove the leading glyph and unicode context bar.
- `PULSE_COLOR`: defaults to `true`. Set to `false` to disable ANSI colors.
- `PULSE_NOTIFY`: defaults to auto detection. Use `osa`, `osc9`, `bell`, or `off`.

The status line script also has a small top of file config block where you can reorder or disable segments with `PULSE_SEGMENTS`.

## How It Works

Codex runs the configured status command on each status refresh and sends one JSON object on stdin. The first line printed by `statusline.sh` is rendered in the TUI footer, including ANSI styling when enabled.

## Test

```sh
echo '{"model":"gpt-5.5","cwd":"'"$PWD"'","context_window":{"used":120000,"total":400000}}' | ./statusline.sh
```

For notifications:

```sh
echo '{"hook_event_name":"Notification","cwd":"'"$PWD"'","session_id":"demo","model":"gpt-5.5"}' | ./hooks/notify.sh
```

## License

MIT, copyright 2026 Martino Yovo.
