#!/bin/sh

###############################################################################
# codex-pulse user config
#
# Flip these with environment variables, or edit the defaults below after
# installing to ~/.codex/codex-pulse/statusline.sh.
###############################################################################
: "${USE_NERD_FONTS:=true}"
: "${PULSE_COLOR:=true}"

# Reorder or remove segment names to change the footer. Valid names:
# model project branch context
: "${PULSE_SEGMENTS:=model project branch context}"
###############################################################################

payload=$(cat 2>/dev/null) || payload=
[ -n "$payload" ] || exit 0

is_on() {
    case "$1" in
        0|false|FALSE|no|NO|off|OFF) return 1 ;;
        *) return 0 ;;
    esac
}

json_parse_python() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 -c '
import json
import os
import sys

try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    print("ERR")
    sys.exit(0)

if not isinstance(data, dict):
    print("ERR")
    sys.exit(0)

def text(value):
    return value if isinstance(value, str) else ""

def number(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None

def first_number(source, names):
    if not isinstance(source, dict):
        return None
    for name in names:
        value = number(source.get(name))
        if value is not None:
            return value
    return None

model = text(data.get("model"))
cwd = text(data.get("cwd"))

root = ""
for key in ("project_root", "workspace_root", "root", "directory"):
    root = text(data.get(key))
    if root:
        break
if not root:
    for key in ("workspace", "workspace_info", "project"):
        value = data.get(key)
        if isinstance(value, dict):
            for inner in ("project_root", "workspace_root", "root", "directory", "cwd"):
                root = text(value.get(inner))
                if root:
                    break
        if root:
            break

base = root or cwd
project = os.path.basename(os.path.normpath(base)) if base else ""

ctx = data.get("context_window")
if not isinstance(ctx, dict):
    ctx = {}

used = first_number(ctx, ("used", "used_tokens", "tokens_used", "current"))
total = first_number(ctx, ("total", "total_tokens", "context_window", "max", "max_tokens", "limit"))
remaining = first_number(ctx, ("remaining", "remaining_tokens", "tokens_remaining", "available"))

percent = ""
if used is not None and total and total > 0:
    percent = round((used / total) * 100)
elif used is not None and remaining is not None and (used + remaining) > 0:
    percent = round((used / (used + remaining)) * 100)
elif total and remaining is not None and total > 0:
    percent = round(((total - remaining) / total) * 100)

if percent != "":
    percent = max(0, min(100, int(percent)))

print("OK")
for value in (model, cwd, project, str(percent) if percent != "" else ""):
    print(value)
' 2>/dev/null
}

json_string_sed() {
    key=$1
    printf '%s' "$payload" |
        sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        sed -n '1p'
}

json_number_sed() {
    key=$1
    printf '%s' "$payload" |
        sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' |
        sed -n '1p'
}

parsed=$(printf '%s' "$payload" | json_parse_python) || parsed=
parse_status=$(printf '%s\n' "$parsed" | sed -n '1p')
if [ "$parse_status" = "ERR" ]; then
    exit 0
elif [ "$parse_status" = "OK" ]; then
    MODEL=$(printf '%s\n' "$parsed" | sed -n '2p')
    CWD=$(printf '%s\n' "$parsed" | sed -n '3p')
    PROJECT=$(printf '%s\n' "$parsed" | sed -n '4p')
    CTX_PERCENT=$(printf '%s\n' "$parsed" | sed -n '5p')
else
    MODEL=$(json_string_sed model)
    CWD=$(json_string_sed cwd)
    PROJECT=
    if [ -n "$CWD" ]; then
        PROJECT=$(basename "$CWD" 2>/dev/null || printf '')
    fi
    used=$(json_number_sed used)
    total=$(json_number_sed total)
    remaining=$(json_number_sed remaining)
    CTX_PERCENT=
    if [ -n "$used" ] && [ -n "$total" ] && awk "BEGIN { exit !($total > 0) }" 2>/dev/null; then
        CTX_PERCENT=$(awk "BEGIN { pct=($used/$total)*100; printf \"%d\", pct + 0.5 }" 2>/dev/null)
    elif [ -n "$used" ] && [ -n "$remaining" ] && awk "BEGIN { exit !(($used+$remaining) > 0) }" 2>/dev/null; then
        CTX_PERCENT=$(awk "BEGIN { pct=($used/($used+$remaining))*100; printf \"%d\", pct + 0.5 }" 2>/dev/null)
    fi
fi

BRANCH=
DIRTY=
if [ -n "$CWD" ] && [ -d "$CWD" ] && command -v git >/dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null) || BRANCH=
    if [ "$BRANCH" = "HEAD" ]; then
        BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null) || BRANCH=
    fi
    if [ -n "$BRANCH" ] && [ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ]; then
        DIRTY='*'
    fi
fi

if is_on "$PULSE_COLOR"; then
    esc=$(printf '\033')
    RESET="${esc}[0m"
    DIM="${esc}[2m"
    ACCENT="${esc}[36m"
    OK="${esc}[32m"
    WARN="${esc}[33m"
else
    RESET=
    DIM=
    ACCENT=
    OK=
    WARN=
fi

bar_for_percent() {
    pct=$1
    [ -n "$pct" ] || return 0
    filled=$(( (pct * 7 + 50) / 100 ))
    [ "$filled" -lt 0 ] && filled=0
    [ "$filled" -gt 7 ] && filled=7
    i=0
    while [ "$i" -lt 7 ]; do
        if [ "$i" -lt "$filled" ]; then
            printf '▓'
        else
            printf '░'
        fi
        i=$((i + 1))
    done
}

append_segment() {
    value=$1
    [ -n "$value" ] || return 0
    if [ -n "$line" ]; then
        line="${line} · ${value}"
    else
        line=$value
    fi
}

line=
for segment in $PULSE_SEGMENTS; do
    case "$segment" in
        model)
            [ -n "$MODEL" ] && append_segment "${DIM}${ACCENT}${MODEL}${RESET}"
            ;;
        project)
            [ -n "$PROJECT" ] && append_segment "$PROJECT"
            ;;
        branch)
            if [ -n "$BRANCH" ]; then
                if [ -n "$DIRTY" ]; then
                    append_segment "${WARN}${BRANCH}${DIRTY}${RESET}"
                else
                    append_segment "$BRANCH"
                fi
            fi
            ;;
        context)
            if [ -n "$CTX_PERCENT" ]; then
                ctx_color=$OK
                [ "$CTX_PERCENT" -ge 80 ] 2>/dev/null && ctx_color=$WARN
                if is_on "$USE_NERD_FONTS"; then
                    append_segment "ctx ${CTX_PERCENT}% ${ctx_color}$(bar_for_percent "$CTX_PERCENT")${RESET}"
                else
                    append_segment "ctx ${CTX_PERCENT}%"
                fi
            fi
            ;;
    esac
done

[ -n "$line" ] || exit 0
if is_on "$USE_NERD_FONTS"; then
    printf '◆ %s\n' "$line"
else
    printf '%s\n' "$line"
fi

exit 0
