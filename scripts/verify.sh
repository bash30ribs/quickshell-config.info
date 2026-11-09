#!/usr/bin/env bash
# Verification Hook & Linter for QuickShell / QML Codebase
# Validates QML syntax after edits and outputs standard hook JSON response
set -e

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Auto-recompile liquid glass shader if source is modified:
if [[ -f "$WORKSPACE_ROOT/effects/glass/liquidglass.frag" ]]; then
    if [[ ! -f "$WORKSPACE_ROOT/effects/glass/liquidglass.frag.qsb" || "$WORKSPACE_ROOT/effects/glass/liquidglass.frag" -nt "$WORKSPACE_ROOT/effects/glass/liquidglass.frag.qsb" ]]; then
        if [ -x /usr/lib/qt6/bin/qsb ]; then
            /usr/lib/qt6/bin/qsb --qt6 -o "$WORKSPACE_ROOT/effects/glass/liquidglass.frag.qsb" "$WORKSPACE_ROOT/effects/glass/liquidglass.frag" >/dev/null 2>&1 || true
        fi
    fi
fi

# If executed directly with --all flag:
if [[ "$1" == "--all" ]]; then
    echo "Validating all QML files across workspace..."
    ERRORS=0
    while IFS= read -r -d '' file; do
        if ! qmlformat "$file" >/dev/null 2>&1; then
            echo "❌ QML syntax error: $file" >&2
            ERRORS=$((ERRORS + 1))
        fi
    done < <(find "$WORKSPACE_ROOT" -name "*.qml" -not -path "*/.*" -print0)
    if [ $ERRORS -gt 0 ]; then
        echo "Validation failed with $ERRORS error(s)." >&2
        exit 1
    fi
    echo "✅ All QML files passed syntax validation."
    exit 0
elif [[ -n "$1" && -f "$1" ]]; then
    if [[ "$1" == *.qml ]]; then
        qmlformat "$1" >/dev/null 2>&1 || { echo "❌ Syntax error in $1" >&2; exit 1; }
        echo "✅ $1 is valid."
    fi
    exit 0
fi

# Antigravity Lifecycle Mode: Read stdin JSON payload
PAYLOAD=$(cat)

FILE_PATH=$(echo "$PAYLOAD" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    args = data.get("toolCall", {}).get("args", {})
    print(args.get("Path", "") or args.get("path", ""))
except Exception:
    print("")
' 2>/dev/null || true)

if [[ -n "$FILE_PATH" && "$FILE_PATH" == *.qml && -f "$FILE_PATH" ]]; then
    if ! qmlformat "$FILE_PATH" >/dev/null 2>&1; then
        echo "Syntax error in $FILE_PATH detected by qmlformat" >&2
        exit 1
    fi
fi

# Output expected JSON object on stdout
echo "{}"
