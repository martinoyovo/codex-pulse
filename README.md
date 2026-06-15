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
- The first time Codex sees this hook, open `/hooks` in the CLI and trust it.
- Hooks are not supported on Windows.

## Configuration

Environment variables:

- `PULSE_NOTIFY`: defaults to auto detection. Use `terminal-notifier`, `alerter`, `osa`, `osc9`, `bell`, or `off`.
- `PULSE_NOTIFY_ICON`: optional image path for `terminal-notifier`. Defaults to the local Codex app icon at `/Applications/Codex.app/Contents/Resources/icon.icns` when present.
- `PULSE_NOTIFY_SENDER`: optional macOS bundle id for `terminal-notifier`. Defaults to `com.openai.codex` when `/Applications/Codex.app` exists, so notifications use Codex as the sender.

On macOS, the built-in `osascript` fallback may show notifications as Script Editor and clicking them may open Script Editor. Install `terminal-notifier` or `alerter` if you want a cleaner notification source:

```sh
brew install terminal-notifier
```

## How It Works

Codex runs configured hooks for lifecycle events and sends one JSON object on stdin. `hooks/notify.sh` reads the hook event name and sends a quick local alert for `Stop` and `PermissionRequest`.

## Test

```sh
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'","session_id":"demo","model":"gpt-5.5"}' | ./hooks/notify.sh
```

## License

MIT, copyright 2026 Martino Yovo.
