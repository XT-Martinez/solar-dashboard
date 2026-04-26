#!/usr/bin/env bash
set -euo pipefail

INFLUX_ORG="${INFLUX_ORG:-solar}"
INFLUX_BUCKET="${INFLUX_BUCKET:-solar}"
INFLUX_TOKEN="${INFLUX_TOKEN:-solar-token}"
INFLUX_DOWNSAMPLED_BUCKET="${INFLUX_DOWNSAMPLED_BUCKET:-${INFLUX_BUCKET}_1m}"
BACKFILL_START="${BACKFILL_START:--90d}"

docker compose exec influxdb influx query --org "${INFLUX_ORG}" --token "${INFLUX_TOKEN}" '
from(bucket: "'"${INFLUX_BUCKET}"'")
  |> range(start: '"${BACKFILL_START}"')
  |> filter(fn: (r) => r._measurement == "sungrow")
  |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)
  |> to(bucket: "'"${INFLUX_DOWNSAMPLED_BUCKET}"'", org: "'"${INFLUX_ORG}"'")
' >/dev/null

printf 'Backfilled %s into %s from %s.\n' "${INFLUX_BUCKET}" "${INFLUX_DOWNSAMPLED_BUCKET}" "${BACKFILL_START}"
