#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if docker compose version >/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

cat <<EOF
Started solar realtime PoC.

Grafana:  http://localhost:3000
Kiosk:    $(./scripts/kiosk-url.sh)
InfluxDB: http://localhost:8086

Useful checks:
  docker compose logs -f telegraf
  docker compose exec influxdb influx query --org solar --token solar-token 'from(bucket: "solar") |> range(start: -5m)'

If temperature is empty or wrong, restart with:
  INSIDE_TEMP_REGISTER=5008 docker compose up -d --force-recreate telegraf
EOF
