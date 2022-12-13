#!/usr/bin/env bash
#
# Provision Grafana dashboards
#
# Usage: ./provision-dashboards.sh [stage-name]
#
# stage-name -- should match a folder name in ./grafana/config/
#

set -e

source "$(dirname "$0")/funs.inc"

set_params_var "$@"
sync_dashboards
