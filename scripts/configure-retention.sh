#!/usr/bin/env bash
set -euo pipefail

INFLUX_ORG="${INFLUX_ORG:-solar}"
INFLUX_BUCKET="${INFLUX_BUCKET:-solar}"
INFLUX_TOKEN="${INFLUX_TOKEN:-solar-token}"
INFLUX_HOST="${INFLUX_HOST:-http://127.0.0.1:8086}"
INFLUX_DOWNSAMPLED_BUCKET="${INFLUX_DOWNSAMPLED_BUCKET:-${INFLUX_BUCKET}_1m}"
INFLUX_RAW_RETENTION="${INFLUX_RAW_RETENTION:-2160h}"
INFLUX_DOWNSAMPLED_RETENTION="${INFLUX_DOWNSAMPLED_RETENTION:-17520h}"
INFLUX_DOWNSAMPLE_TASK="${INFLUX_DOWNSAMPLE_TASK:-downsample-${INFLUX_BUCKET}-1m}"
INFLUX_WAIT_ATTEMPTS="${INFLUX_WAIT_ATTEMPTS:-60}"

influx() {
  INFLUX_HOST="${INFLUX_HOST}" INFLUX_TOKEN="${INFLUX_TOKEN}" command influx "$@"
}

wait_for_influxdb() {
  local attempt
  for ((attempt = 1; attempt <= INFLUX_WAIT_ATTEMPTS; attempt++)); do
    if influx ping >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
  done

  printf 'InfluxDB did not become ready after %s seconds.\n' "${INFLUX_WAIT_ATTEMPTS}" >&2
  return 1
}

bucket_id() {
  local bucket_name="$1"
  { influx bucket list --org "${INFLUX_ORG}" --name "${bucket_name}" --hide-headers 2>/dev/null || true; } | awk 'NF {print $1; exit}'
}

wait_for_influxdb

raw_bucket_id="$(bucket_id "${INFLUX_BUCKET}")"
if [[ -z "${raw_bucket_id}" ]]; then
  printf 'Bucket %s does not exist. Start the stack first.\n' "${INFLUX_BUCKET}" >&2
  exit 1
fi

influx bucket update --id "${raw_bucket_id}" --retention "${INFLUX_RAW_RETENTION}"

downsampled_bucket_id="$(bucket_id "${INFLUX_DOWNSAMPLED_BUCKET}")"
if [[ -z "${downsampled_bucket_id}" ]]; then
  influx bucket create --org "${INFLUX_ORG}" --name "${INFLUX_DOWNSAMPLED_BUCKET}" --retention "${INFLUX_DOWNSAMPLED_RETENTION}"
else
  influx bucket update --id "${downsampled_bucket_id}" --retention "${INFLUX_DOWNSAMPLED_RETENTION}"
fi

task_file="$(mktemp)"
trap 'rm -f "${task_file}"' EXIT

cat >"${task_file}" <<EOF_TASK
option task = {name: "${INFLUX_DOWNSAMPLE_TASK}", every: 1m}

from(bucket: "${INFLUX_BUCKET}")
  |> range(start: -task.every)
  |> filter(fn: (r) => r._measurement == "sungrow")
  |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)
  |> to(bucket: "${INFLUX_DOWNSAMPLED_BUCKET}", org: "${INFLUX_ORG}")
EOF_TASK

task_id="$(influx task list --org "${INFLUX_ORG}" --hide-headers | awk -v name="${INFLUX_DOWNSAMPLE_TASK}" '$2 == name {print $1; exit}')"
if [[ -z "${task_id}" ]]; then
  influx task create --org "${INFLUX_ORG}" --file "${task_file}"
else
  influx task update --id "${task_id}" --file "${task_file}"
fi

printf 'Configured InfluxDB retention:\n'
printf -- '- %s raw retention: %s\n' "${INFLUX_BUCKET}" "${INFLUX_RAW_RETENTION}"
printf -- '- %s downsampled retention: %s\n' "${INFLUX_DOWNSAMPLED_BUCKET}" "${INFLUX_DOWNSAMPLED_RETENTION}"
printf -- '- task: %s\n' "${INFLUX_DOWNSAMPLE_TASK}"
