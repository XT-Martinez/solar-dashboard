#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if docker compose version >/dev/null 2>&1; then
  docker compose down
else
  docker-compose down
fi

echo "Stopped solar realtime PoC containers. Volumes are left intact."
