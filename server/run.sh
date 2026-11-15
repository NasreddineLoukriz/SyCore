#!/usr/bin/env bash
# Start the blind server on http://127.0.0.1:8787
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d .venv ]; then
  echo "creating .venv …"
  python3 -m venv .venv
  ./.venv/bin/pip -q install --upgrade pip
  ./.venv/bin/pip -q install -r requirements.txt
fi

exec ./.venv/bin/uvicorn sycore_server.main:app --host 127.0.0.1 --port 8787 "$@"
