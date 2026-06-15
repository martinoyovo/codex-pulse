# codex-pulse

A tiny Codex CLI companion that adds desktop friendly turn notifications.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/martinoyovo/codex-pulse/main/install.sh | sh
```

The installer copies the notification hook to `~/.codex/codex-pulse`, enables Codex hooks in `~/.codex/config.toml`, and merges notification hooks into `~/.codex/hooks.json`.

Manual install:

```sh
mkdir -p ~/.codex/codex-pulse
cp hooks/notify.sh ~/.codex/codex-pulse/notify.sh
chmod +x ~/.codex/codex-pulse/notify.sh
```

Then copy the relevant examples from `examples/config-snippet.toml` and `examples/hooks.json`.

## What This Is

`hooks/notify.sh` reads Codex hook JSON and sends a quick alert when a turn finishes or Codex needs attention.

What it needs:

- The notification hook works today wherever Codex hooks are enabled with `[features] hooks = true`.
- Hooks are not supported on Windows.

## Configuration

Environment variables:

- `PULSE_NOTIFY`: defaults to auto detection. Use `osa`, `osc9`, `bell`, or `off`.

## How It Works

Codex runs configured hooks for lifecycle events and sends one JSON object on stdin. `hooks/notify.sh` reads the hook event name and sends a quick local alert for `Stop` and `Notification`.

## Test

```sh
echo '{"hook_event_name":"Notification","cwd":"'"$PWD"'","session_id":"demo","model":"gpt-5.5"}' | ./hooks/notify.sh
```

## License

MIT, copyright 2026 Martino Yovo.
