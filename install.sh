#!/bin/sh

set -u

SCRIPT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd) || exit 1
CODEX_DIR=${CODEX_HOME:-"$HOME/.codex"}
INSTALL_DIR="$CODEX_DIR/codex-pulse"
STATUS_SRC="$SCRIPT_DIR/statusline.sh"
NOTIFY_SRC="$SCRIPT_DIR/hooks/notify.sh"
STATUS_DST="$INSTALL_DIR/statusline.sh"
NOTIFY_DST="$INSTALL_DIR/notify.sh"
CONFIG_FILE="$CODEX_DIR/config.toml"
HOOKS_FILE="$CODEX_DIR/hooks.json"
RAW_URL=${PULSE_RAW_URL:-"https://raw.githubusercontent.com/martinoyovo/codex-pulse/main"}

mkdir -p "$INSTALL_DIR" "$CODEX_DIR"

fetch_file() {
    url=$1
    dst=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dst"
    elif command -v fetch >/dev/null 2>&1; then
        fetch -q -o "$dst" "$url"
    else
        return 1
    fi
}

install_file() {
    src=$1
    url_path=$2
    dst=$3
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        return 0
    fi
    case "$RAW_URL" in
        "")
            printf 'Local source %s was not found.\n' "$src" >&2
            printf 'For piped installs, set PULSE_RAW_URL to the raw repository URL.\n' >&2
            exit 1
            ;;
    esac
    if ! fetch_file "$RAW_URL/$url_path" "$dst"; then
        printf 'Could not download %s/%s.\n' "$RAW_URL" "$url_path" >&2
        exit 1
    fi
}

install_file "$STATUS_SRC" "statusline.sh" "$STATUS_DST"
install_file "$NOTIFY_SRC" "hooks/notify.sh" "$NOTIFY_DST"
chmod +x "$STATUS_DST" "$NOTIFY_DST" || exit 1

status_line='tui_status_line = { command = "'"$STATUS_DST"'" }'

merge_config() {
    if command -v python3 >/dev/null 2>&1; then
        CONFIG_FILE=$CONFIG_FILE STATUS_LINE=$status_line python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["CONFIG_FILE"])
status_line = os.environ["STATUS_LINE"]
text = path.read_text() if path.exists() else ""

if not re.search(r"(?m)^\s*\[features\]\s*$", text):
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n[features]\nhooks = true\n"
else:
    pattern = r"(?ms)^(\s*\[features\]\s*\n)(.*?)(?=^\s*\[|\Z)"
    match = re.search(pattern, text)
    if match:
        body = match.group(2)
        body = re.sub(r"(?m)^\s*codex_hooks\s*=.*\n?", "", body)
        if re.search(r"(?m)^\s*hooks\s*=", body):
            body = re.sub(r"(?m)^(\s*)hooks\s*=.*$", r"\1hooks = true", body)
        else:
            if body and not body.endswith("\n"):
                body += "\n"
            body += "hooks = true\n"
        text = text[:match.start()] + match.group(1) + body + text[match.end():]

marker = "# codex-pulse status line"
if marker not in text:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n" + marker + " (uncomment if your Codex build supports it)\n"
    text += "# " + status_line + "\n"

path.write_text(text)
PY
    else
        if [ ! -f "$CONFIG_FILE" ]; then
            {
                printf '[features]\n'
                printf 'hooks = true\n\n'
                printf '# codex-pulse status line (uncomment if your Codex build supports it)\n'
                printf '# %s\n' "$status_line"
            } > "$CONFIG_FILE"
        else
            printf 'Python 3 was not found, merge this into %s manually:\n' "$CONFIG_FILE"
            printf '[features]\n'
            printf 'hooks = true\n'
            printf '# %s\n' "$status_line"
        fi
    fi
}

merge_hooks() {
    if command -v python3 >/dev/null 2>&1; then
        HOOKS_FILE=$HOOKS_FILE NOTIFY_DST=$NOTIFY_DST python3 - <<'PY'
from pathlib import Path
import json
import os

path = Path(os.environ["HOOKS_FILE"])
notify = os.environ["NOTIFY_DST"]

if path.exists():
    try:
        data = json.loads(path.read_text() or "{}")
    except Exception:
        data = {}
else:
    data = {}

if not isinstance(data, dict):
    data = {}

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}
    data["hooks"] = hooks

for event in ("Stop", "Notification"):
    entries = hooks.setdefault(event, [])
    if not isinstance(entries, list):
        entries = []
        hooks[event] = entries
    exists = any(isinstance(item, dict) and item.get("command") == notify for item in entries)
    if not exists:
        entries.append({"command": notify})

path.write_text(json.dumps(data, indent=2) + "\n")
PY
    else
        if [ ! -f "$HOOKS_FILE" ]; then
            {
                printf '{\n'
                printf '  "hooks": {\n'
                printf '    "Stop": [\n'
                printf '      { "command": "%s" }\n' "$NOTIFY_DST"
                printf '    ],\n'
                printf '    "Notification": [\n'
                printf '      { "command": "%s" }\n' "$NOTIFY_DST"
                printf '    ]\n'
                printf '  }\n'
                printf '}\n'
            } > "$HOOKS_FILE"
        else
            printf 'Python 3 was not found, merge %s manually into %s.\n' "$NOTIFY_DST" "$HOOKS_FILE"
        fi
    fi
}

merge_config
merge_hooks

if command -v codex >/dev/null 2>&1; then
    codex_version=$(codex --version 2>/dev/null || printf 'unknown')
else
    codex_version="not found on PATH"
fi

printf '\ncodex-pulse installed.\n\n'
printf 'Installed files:\n'
printf '  %s\n' "$STATUS_DST"
printf '  %s\n\n' "$NOTIFY_DST"
printf 'Hooks were merged into:\n'
printf '  %s\n\n' "$HOOKS_FILE"
printf 'Codex version check: %s\n' "$codex_version"
printf 'Status line support depends on your Codex build. Add this line to %s when supported:\n' "$CONFIG_FILE"
printf '  %s\n\n' "$status_line"
printf 'Test with:\n'
printf '  %s\n' "echo '{\"model\":\"gpt-5.5\",\"cwd\":\"'\"\$PWD\"'\",\"context_window\":{\"used\":120000,\"total\":400000}}' | $STATUS_DST"

exit 0
