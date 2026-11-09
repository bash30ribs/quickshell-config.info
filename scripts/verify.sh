#!/usr/bin/env bash
# Verification Hook for QuickShell / QML Codebase
# Validates QML syntax after edits and outputs standard hook JSON response
set -e

# Read stdin JSON payload from Antigravity lifecycle
PAYLOAD=$(cat)

# Extract edited file path if present
FILE_PATH=$(echo "$PAYLOAD" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    args = data.get("toolCall", {}).get("args", {})
    print(args.get("Path", "") or args.get("path", ""))
except Exception:
    print("")
' 2>/dev/null || true)

# If file is QML, validate syntax
if [[ -n "$FILE_PATH" && "$FILE_PATH" == *.qml && -f "$FILE_PATH" ]]; then
    if ! qmlformat "$FILE_PATH" >/dev/null 2>&1; then
        echo "Syntax error in $FILE_PATH detected by qmlformat" >&2
        exit 1
    fi
fi

# Return empty JSON object as expected by PostToolUse hook contract
echo "{}"
