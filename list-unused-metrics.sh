#!/usr/bin/env bash
#
# Lists known metrics (see port :9095) that are not used in provisioned dashboards
#
set -e

METRICS_URL=${METRICS_URL?}
DASHBOARDS_PATH=docker-compose/var/lib/grafana/dashboards

if [[ -f /tmp/all-metrics ]]
then
    echo 2>&1 ";; Using existing /tmp/all-metrics file, remove it to fetch new"
else
    echo 2>&1 ";; Fetching all metrics from $METRICS_URL..."
    curl --fail -sS "$METRICS_URL" -o /tmp/all-metrics
fi

grep '"expr"' -r "$DASHBOARDS_PATH/" | sed 's/,$//' | awk '{print $3}' | sort -u > /tmp/used-metrics

awk </tmp/all-metrics '/ TYPE / { print $3, $4 }' | sort -u |
    while read -r metric tpe
    do
        echo "$metric" "$tpe" "$(grep -E "${metric}[^_a-zA-Z0-9]" /tmp/used-metrics || echo MISSED)"
    done
