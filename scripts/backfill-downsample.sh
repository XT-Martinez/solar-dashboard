#!/usr/bin/env bash
set -euo pipefail

INFLUX_ORG="${INFLUX_ORG:-solar}"
INFLUX_BUCKET="${INFLUX_BUCKET:-solar}"
INFLUX_TOKEN="${INFLUX_TOKEN:-solar-token}"
INFLUX_DOWNSAMPLED_BUCKET="${INFLUX_DOWNSAMPLED_BUCKET:-${INFLUX_BUCKET}_1h}"
INFLUX_DOWNSAMPLE_EVERY="${INFLUX_DOWNSAMPLE_EVERY:-1h}"
BACKFILL_START="${BACKFILL_START:--90d}"

docker compose exec influxdb influx query --org "${INFLUX_ORG}" --token "${INFLUX_TOKEN}" '
production = from(bucket: "'"${INFLUX_BUCKET}"'")
  |> range(start: '"${BACKFILL_START}"')
  |> filter(fn: (r) => r._measurement == "sungrow")
  |> filter(fn: (r) => r._field == "total_dc_power_w")
  |> map(fn: (r) => ({ r with _value: float(v: r._value) }))
  |> window(every: '"${INFLUX_DOWNSAMPLE_EVERY}"')
  |> integral(unit: 1h)
  |> map(fn: (r) => ({ r with _time: r._start, _measurement: "sungrow_energy", _field: "production_kwh", _value: r._value / 1000.0 }))
  |> window(every: inf)

consumption = from(bucket: "'"${INFLUX_BUCKET}"'")
  |> range(start: '"${BACKFILL_START}"')
  |> filter(fn: (r) => r._measurement == "sungrow")
  |> filter(fn: (r) => r._field == "load_power_w")
  |> map(fn: (r) => ({ r with _value: float(v: r._value) }))
  |> window(every: '"${INFLUX_DOWNSAMPLE_EVERY}"')
  |> integral(unit: 1h)
  |> map(fn: (r) => ({ r with _time: r._start, _measurement: "sungrow_energy", _field: "consumption_kwh", _value: r._value / 1000.0 }))
  |> window(every: inf)

grid = from(bucket: "'"${INFLUX_BUCKET}"'")
  |> range(start: '"${BACKFILL_START}"')
  |> filter(fn: (r) => r._measurement == "sungrow")
  |> filter(fn: (r) => r._field == "export_power_w")
  |> map(fn: (r) => ({ r with _value: if float(v: r._value) < 0.0 then float(v: r._value) * -1.0 else 0.0 }))
  |> window(every: '"${INFLUX_DOWNSAMPLE_EVERY}"')
  |> integral(unit: 1h)
  |> map(fn: (r) => ({ r with _time: r._start, _measurement: "sungrow_energy", _field: "grid_import_kwh", _value: r._value / 1000.0 }))
  |> window(every: inf)

union(tables: [production, consumption, grid])
  |> keep(columns: ["_time", "_measurement", "_field", "_value"])
  |> to(bucket: "'"${INFLUX_DOWNSAMPLED_BUCKET}"'", org: "'"${INFLUX_ORG}"'")
' >/dev/null

printf 'Backfilled %s into %s from %s using %s windows.\n' "${INFLUX_BUCKET}" "${INFLUX_DOWNSAMPLED_BUCKET}" "${BACKFILL_START}" "${INFLUX_DOWNSAMPLE_EVERY}"
