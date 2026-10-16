#!/usr/bin/env bash
# Container entrypoint: fetch the pinned model and template on first run, then serve.
set -euo pipefail
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Take the paths from the launcher so this never disagrees with what it will open.
paths="$(source "$scripts/q3-env.sh" && printf '%s\n%s\n' "$model" "$template")"
model="$(sed -n 1p <<<"$paths")"
template="$(sed -n 2p <<<"$paths")"
directory="$(dirname "$model")"
if [[ "${1:-}" != --print-config && ( ! -f "$model" || ! -f "$template" ) ]]; then
    if [[ -n "${MODEL_PATH:-}${CHAT_TEMPLATE_PATH:-}" ]]; then
        echo "MODEL_PATH or CHAT_TEMPLATE_PATH points to a missing file." >&2
        exit 2
    fi
    if [[ ! -w "$directory" ]]; then
        echo "The model is not in $directory, and it is not writable to download it." >&2
        echo "Mount a writable volume there, for example -v routeweaver-models:$directory" >&2
        echo "or mount a directory populated by scripts/download-q3.sh. See docs/container.md." >&2
        exit 2
    fi
    echo "Downloading the pinned model and template into $directory (about 10.6 GB)."
    MODEL_DIR="$directory" "$scripts/download-q3.sh"
fi
exec "$scripts/serve-q3.sh" "$@"
