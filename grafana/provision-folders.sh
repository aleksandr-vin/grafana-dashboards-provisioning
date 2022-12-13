#!/usr/bin/env bash
#
# Provision Grafana folders
#
# Usage: ./provision-folders.sh
#

set -e

source "$(dirname "$0")/funs.inc"

sync_folders
