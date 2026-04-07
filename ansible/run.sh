#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENCRYPTED="$SCRIPT_DIR/vars/sensitive.yml"

[[ -f "$ENCRYPTED" ]] || { echo "Missing $ENCRYPTED"; exit 1; }

TMPFILE=$(mktemp --suffix=.yml)
trap 'rm -f "$TMPFILE"' EXIT INT TERM

sops -d "$ENCRYPTED" > "$TMPFILE" || { echo "Failed to decrypt $ENCRYPTED"; exit 1; }

cd "$SCRIPT_DIR"
cmd="$1"; shift
"$cmd" -e "@$TMPFILE" "$@"
