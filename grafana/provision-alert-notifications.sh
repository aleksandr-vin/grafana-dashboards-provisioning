#!/usr/bin/env bash
#
# Provision Grafana alert notifications
#
# Usage: ./provision-alert-notifications.sh [stage-name]
#
# stage-name -- should match a folder name in ./grafana/config/
#

set -e

source "$(dirname "$0")/funs.inc"

set_params_var "$@"
sync_notifiers
