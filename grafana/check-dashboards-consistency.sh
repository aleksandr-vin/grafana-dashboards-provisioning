#!/usr/bin/env bash
#
# Check that all dashboards in *.json files convert to *.yaml files and back
#

set -e

for f in "$@"
do
  case "$f" in
    *.json)
      name="${f%%.json}"
      echo "checking $name.json -> $name.yaml"
      yq e -P 'sort_keys(..)' </dev/null "$name".json >"$name".json-to-yaml
      diff "$name".{yaml,json-to-yaml}
      rm "$name".json-to-yaml
      ;;
    *.yaml)
      name="${f%%.yaml}"
      echo "checking $name.yaml-> $name.json"
      yq e -P 'sort_keys(..)' -o=json </dev/null "$name".yaml >"$name".yaml-to-json
      diff "$name".{json,yaml-to-json}
      rm "$name".yaml-to-json
      ;;
    *)
      echo >&2 "Unknown file: $f"
      exit 11
  esac
done
