#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
DASHBOARD_UID="${DASHBOARD_UID:-sungrow-realtime}"
DASHBOARD_SLUG="${DASHBOARD_SLUG:-sungrow-realtime}"
TIME_RANGE="${TIME_RANGE:-now-6h}"
REFRESH="${REFRESH:-5s}"

printf '%s/d/%s/%s?orgId=1&from=%s&to=now&refresh=%s&kiosk\n' \
  "${GRAFANA_URL}" \
  "${DASHBOARD_UID}" \
  "${DASHBOARD_SLUG}" \
  "${TIME_RANGE}" \
  "${REFRESH}"
