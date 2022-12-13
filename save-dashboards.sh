#!/bin/bash

#
# A fixed version of script from https://ops.tips/blog/initialize-grafana-with-preconfigured-dashboards/#updating-dashboards
#

# Updates local dashboard configurations by retrieving
# the new version from a Grafana instance.
#
# The script assumes that basic authentication is configured
# (change the login credentials with `LOGIN`).
#
# DASHBOARD_DIRECTORY represents the path to the directory
# where the JSON files corresponding to the dashboards exist.
# The default location is relative to the execution of the
# script.
#
# URL specifies the URL of the Grafana instance.
#
# Usage:  ./save-dashboards.sh [with-shared-annotations] [list]
#
#   with-shared-annotations  -  splice shared annotations (see grafana/shared-annotations.jsonnet) into the saved dashboard
#
#   list                     -  list dashboards and stop, output can be used in DASHBOARDS env var
#

set -o errexit

readonly URL=${URL:-"http://localhost:3000"}
readonly LOGIN=${LOGIN:-"admin:admin"}
readonly DASHBOARDS_DIRECTORY=${DASHBOARDS_DIRECTORY:-"./docker-compose/var/lib/grafana/dashboards"}


main() {
  local dashboards
  dashboards=${DASHBOARDS:-$(list_dashboards)}
  local dashboard_json

  #  show_config

  SHARED_ANNOTATIONS_FILE=$(mktemp)
  #  trap "rm $SHARED_ANNOTATIONS_FILE" EXIT
  echo '[]' >"$SHARED_ANNOTATIONS_FILE"
  case "$@" in
      with-shared-annotations)
          jsonnet grafana/shared-annotations.jsonnet >"$SHARED_ANNOTATIONS_FILE"
          ;;
      list)
          list_dashboards
          exit 1
          ;;
      *)
          ;;
  esac

  echo "Dumping dashboards from $URL into $DASHBOARDS_DIRECTORY" >&2

  echo "$dashboards" | while read -r dashboard; do

    echo -n "$(echo "$dashboard" | jq -r '"\(.id): \(.title)"')"
    dashboard_json=$(get_dashboard "$(echo "$dashboard" | jq --sort-keys -r '.uid')")

    if [[ -z "$dashboard_json" ]]; then
      echo "Error: couldn't retrieve dashboard $dashboard." >&2
      exit 1
    fi

    filename=$(echo "$dashboard" | jq -r '.uri' | cut -d '/' -f2)
    echo "$dashboard_json" \
        | jq '.annotations.list=(.annotations.list + $shared_annotations[] | group_by(.name) | map(.[-1]))' \
             --slurpfile shared_annotations "$SHARED_ANNOTATIONS_FILE" \
        | jq '(..|objects|select(has("datasource"))|select(.datasource!="-- Grafana --").datasource?) |= "Kubernetes"' \
        >"$DASHBOARDS_DIRECTORY/$filename.json"
    echo -n " ===> $DASHBOARDS_DIRECTORY/$filename.json" >&2
    yq -P eval 'sort_keys(..)' </dev/null "$DASHBOARDS_DIRECTORY/$filename.json" >"$DASHBOARDS_DIRECTORY/$filename.yaml"
    yq -P eval 'sort_keys(..)' -o=json </dev/null "$DASHBOARDS_DIRECTORY/$filename.yaml" >"$DASHBOARDS_DIRECTORY/$filename.json-out"
    if diff "$DASHBOARDS_DIRECTORY/$filename.json" "$DASHBOARDS_DIRECTORY/$filename.json-out"
    then
      rm "$DASHBOARDS_DIRECTORY/$filename.json-out"
      echo " ==> $DASHBOARDS_DIRECTORY/$filename.yaml" >&2
    else
      echo " ==X $DASHBOARDS_DIRECTORY/$filename.yaml" >&2
      echo " !!!! Conversion to YAML was not revertible !!!!" >&2
    fi
  done
}


# Shows the global environment variables that have been configured
# for this run.
show_config() {
  echo "INFO:
  Starting dashboard extraction.

  URL:                  $URL
  LOGIN:                $LOGIN
  DASHBOARDS_DIRECTORY: $DASHBOARDS_DIRECTORY
  "
}


# Retrieves a dashboard ($1) from the database of dashboards.
#
# As we're getting it right from the database, it'll contain an `id`.
#
# Given that the ID is potentially different when we import it
# later, to make this dashboard importable we make the `id`
# field NULL.
get_dashboard() {
  local uid
  uid=${1?A dashboard UID must be specified.}
  curl \
      --silent \
      --fail \
    --user "$LOGIN" \
    "$URL/api/dashboards/uid/$uid" |
      jq '.dashboard | .id = null'
}


# lists all the dashboards available.
#
# `/api/search` lists all the dashboards and folders
# that exist in our organization.
#
# Here we filter the response (that also contain folders)
# to gather only the name of the dashboards.
list_dashboards() {
  echo "Fetching all dashboards..." >&2
  curl \
      --silent \
      --fail \
    --user "$LOGIN" \
    "$URL/api/search" |
    jq -c -r '.[] | select(.type == "dash-db")'
}

main "$@"
