#!/bin/sh

payload=$(cat 2>/dev/null) || payload=
[ -n "$payload" ] || exit 0

case "$(uname -s 2>/dev/null)" in
    CYGWIN*|MINGW*|MSYS*|Windows_NT*) exit 0 ;;
esac

event=
if command -v python3 >/dev/null 2>&1; then
    event=$(printf '%s' "$payload" | python3 -c '
import json
import sys
try:
    value = json.loads(sys.stdin.read() or "{}").get("hook_event_name", "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")
' 2>/dev/null) || event=
fi

if [ -z "$event" ]; then
    event=$(printf '%s' "$payload" |
        sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        sed -n '1p')
fi

case "$event" in
    Stop) message="Codex finished" ;;
    PermissionRequest|Notification) message="Codex needs you" ;;
    *) exit 0 ;;
esac

notify_icon() {
    if [ -n "${PULSE_NOTIFY_ICON:-}" ] && [ -f "$PULSE_NOTIFY_ICON" ]; then
        printf '%s' "$PULSE_NOTIFY_ICON"
        return 0
    fi
    if [ -f "/Applications/Codex.app/Contents/Resources/icon.icns" ]; then
        printf '%s' "/Applications/Codex.app/Contents/Resources/icon.icns"
        return 0
    fi
    return 1
}

notify_sender() {
    if [ -n "${PULSE_NOTIFY_SENDER:-}" ]; then
        printf '%s' "$PULSE_NOTIFY_SENDER"
        return 0
    fi
    if [ -d "/Applications/Codex.app" ]; then
        printf '%s' "com.openai.codex"
        return 0
    fi
    return 1
}

notify_terminal_notifier() {
    command -v terminal-notifier >/dev/null 2>&1 || return 1
    icon=$(notify_icon || printf '')
    sender=$(notify_sender || printf '')
    if [ -n "$sender" ]; then
        terminal-notifier \
            -title "Codex" \
            -message "$message" \
            -group "codex-pulse" \
            -sender "$sender" \
            >/dev/null 2>&1 &
        return 0
    fi
    if [ -n "$icon" ]; then
        terminal-notifier \
            -title "Codex" \
            -message "$message" \
            -group "codex-pulse" \
            -appIcon "$icon" \
            >/dev/null 2>&1 &
        return 0
    fi
    terminal-notifier \
        -title "Codex" \
        -message "$message" \
        -group "codex-pulse" \
        >/dev/null 2>&1 &
    return 0
}

notify_alerter() {
    command -v alerter >/dev/null 2>&1 || return 1
    alerter \
        -title "Codex" \
        -message "$message" \
        -group "codex-pulse" \
        >/dev/null 2>&1 &
    return 0
}

notify_osa() {
    command -v osascript >/dev/null 2>&1 || return 1
    osascript -e "display notification \"$message\" with title \"Codex\"" >/dev/null 2>&1 &
    return 0
}

notify_osc9() {
    printf '\033]9;%s\007' "$message"
}

notify_bell() {
    printf '\a'
}

case "${PULSE_NOTIFY:-auto}" in
    off) ;;
    terminal-notifier|notifier) notify_terminal_notifier || notify_osa || notify_osc9 ;;
    alerter) notify_alerter || notify_osa || notify_osc9 ;;
    osa) notify_osa || notify_osc9 ;;
    osc9) notify_osc9 ;;
    bell) notify_bell ;;
    *)
        notify_terminal_notifier || notify_alerter || notify_osa || notify_osc9 || notify_bell
        ;;
esac

exit 0
