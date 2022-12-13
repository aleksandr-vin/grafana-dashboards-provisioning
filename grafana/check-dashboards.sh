#!/usr/bin/env bash
#
# Check dashboards:
#
# - Duplicated panels id
# - Missing tags
#

set -e

for f in "$@"
do
    case "$f" in
        *.yaml)
            echo "- for duplicated id-s"
            ids=$(yq e '(.panels[]|.id) , (.panels[]|select(has("panels")).panels[]|.id)' </dev/null "$f")
            if ! diff <(echo "$ids" | sort -n -u) <(echo "$ids" | sort -n)
            then
                echo "!! DUPLICATED PANEL ID-S FOUND !!"
                exit 1
            fi

            echo -n "- for missing tags"
            tags=$(yq e '.tags[]' </dev/null "$f")
            if [[ "$tags" == "" ]]
            then
                echo ": !!! NO TAGS FOUND !!!"
                exit 1
            else
                echo ""
            fi
            ;;
        *)
            echo >&2 "Unknown file: $f"
            exit 11
    esac
done
