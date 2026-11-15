#!/usr/bin/env bash
# Start clean: stop the server, delete its database, delete the app's local
# vaults, start the server again. One command before a demonstration.
set -euo pipefail
cd "$(dirname "$0")"

PORT=8787
PID=$( (ss -ltnp 2>/dev/null || true) | grep ":$PORT" | grep -oP 'pid=\K[0-9]+' | head -1 || true)
if [ -n "${PID:-}" ]; then
  echo "stopping server pid $PID"
  kill "$PID" 2>/dev/null || true
  sleep 1
fi

rm -f sycore.db sycore.db-wal sycore.db-shm
rm -rf "${SYCORE_HOME:-$HOME/.sycore/app}"
mkdir -p "${SYCORE_HOME:-$HOME/.sycore/app}"

echo "database and local vaults cleared"
echo "starting server on http://127.0.0.1:$PORT …"
exec ./run.sh
