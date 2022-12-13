# -*- mode: shell-script -*-
#
# Provision Grafana shared functions
#
# Set DEBUG=1 env var for verbose logging
#

set -e
#set -x

PROVISION_CONFIG_PATH=${PROVISION_CONFIG_PATH-$(dirname $0)}/config

GRAFANA_URL=${GRAFANA_URL-"http://admin:admin@localhost:3000"}
FOLDERS_URL=${FOLDERS_URL-"${GRAFANA_URL}/api/folders"}
ALERT_NOTIFICATIONS_URL=${ALERT_NOTIFICATIONS_URL-"${GRAFANA_URL}/api/alert-notifications"}
DASHBOARDS_URL=${DASHBOARDS_URL-"${GRAFANA_URL}/api/dashboards"}

FOLDERS_YAML="${PROVISION_CONFIG_PATH}/folders.yaml"
NOTIFIERS_YAML="$(dirname $0)/../docker-compose/etc/grafana/provisioning/notifiers/all.yaml"
DASHBOARDS_DIR="$(dirname $0)/../docker-compose/var/lib/grafana/dashboards"


CURL() {
    # To use the authentication from your current session in browser,
    # open Developer console > Network tab and find any request with cookies,
    # then right-click and "Copy as cURL". Now run the script with LOAD_CURL_HEADERS_FROM_PB=yes env var
    if [[ "$LOAD_CURL_HEADERS_FROM_PB" == "yes" ]]
    then
        CURL_PARAMS+=(-H "$(pbpaste | ggrep -P -o -- "'\KCookie: .*(?=')")")
        CURL_PARAMS+=(-H "$(pbpaste | ggrep -P -o -- "'\Kx-grafana-org-id: .*(?=')")")
    fi
    curl \
        $(echo "${DEBUG+ -v}") \
        $(echo "${DEBUG- --show-error --silent}") \
        --fail "$@" \
        "${CURL_PARAMS[@]}"
}

set_params_var() {
    stage="${1?Specify env: $((cd ${PROVISION_CONFIG_PATH}/config && ls -d */ | tr -d /))}"
    ENV_PARAMS_YAML="${PROVISION_CONFIG_PATH}/${stage}/params.yaml"
    if [[ ! -f "${ENV_PARAMS_YAML}" ]]
    then
        exit 1
    fi
}

upsert_dashboard() {
    local file="${1?Specify json file}"
    echo >&2 ";; Creating / updating dashboard with uid $uid"
    CURL "$DASHBOARDS_URL/db" \
        -X POST \
        -H 'Content-Type: application/json;charset=utf-8' \
        --data-binary @"$file" && echo ''
}

get_dashboard() {
    local uid="${1?Specify uid}"
    echo >&2 ";; Fetching dashboard with uid $uid"
    CURL "$DASHBOARDS_URL/uid/$uid"
}

create_or_update_dashboard() {
    local uid="${1?Specify uid}"
    yq ea -o=json ".|select(.uid==\"$uid\")" </dev/null "$DASHBOARDS_DIR"/*.json >.dashboard.json
    # Update alerts' names prefixes
    # shellcheck disable=SC2016
    yq ea -o=json --inplace 'select(fileIndex==1).alert.name_prefix as $foo | (select(fileIndex==0)|.panels[]|select(has("alert"))|.alert.name?) |= sub("\[REPLACE-ME\]", $foo) | select(fileIndex==0)' </dev/null .dashboard.json "$ENV_PARAMS_YAML"
    # Update datasource
    yq ea -o=json --inplace 'select(fileIndex==1).datasource as $foo | (select(fileIndex==0)|..|select($foo != null and has("datasource") and .datasource != "-- Grafana --")|.datasource?) |= $foo | select(fileIndex==0)' </dev/null .dashboard.json "$ENV_PARAMS_YAML"
    (get_dashboard "$uid" || echo '') > .existing-dashboard.json
    if diff <(yq e -o=json '.dashboard|sort_keys(..)|.id=null|.version=null' </dev/null .existing-dashboard.json) \
            <(yq e -o=json 'sort_keys(..)|.id=null|.version=null' </dev/null .dashboard.json) \
            >&2
    then
        echo >&2 ";;; No changes found"
    else
        echo >&2 ";;; Changes"
        change_message=$(git describe --tags --dirty)
        export change_message
        yq ea -o=json "select(fileIndex==0) * {\"dashboard\": select(fileIndex==1)}|.message=strenv(change_message)" </dev/null dashboard-change-template.yaml .dashboard.json >.dashboard-change.json
        upsert_dashboard .dashboard-change.json
    fi
}

sync_dashboards() {
    for uid in $(yq eval --no-doc '.uid' </dev/null "$DASHBOARDS_DIR"/*)
    do
        create_or_update_dashboard "$uid"
    done
}

get_notifier_id() {
    name="${1?Specify alert notification name}"
    CURL "$ALERT_NOTIFICATIONS_URL" -o.alert-notifications
    yq e -o=json ".[]|select(.name==\"${name}\")|.id" </dev/null .alert-notifications
}

merge_notifier() {
    yq ea -o=json "select(fileIndex==0) * select(fileIndex==1).slack" </dev/null "$1" "${ENV_PARAMS_YAML}"
}

create_notifier() {
    name="${1?Specify alert notification name}"
    yq e ".notifiers[]|select(.name==\"${name}\")" </dev/null "$NOTIFIERS_YAML" >.template-notifier.yaml
    merge_notifier .template-notifier.yaml >.notifier.json
    CURL "$ALERT_NOTIFICATIONS_URL" \
          -H 'Content-Type: application/json;charset=utf-8' \
          --data-binary @.notifier.json && echo ''
}

update_notifier() {
    name="${1?Specify alert notification name}"
    an_id="${2?Specify alert notification id}"
    yq e ".notifiers[]|select(.name==\"${name}\")|.id=${an_id}" </dev/null "$NOTIFIERS_YAML" >.template-notifier.yaml
    merge_notifier .template-notifier.yaml >.notifier.json
    CURL "$ALERT_NOTIFICATIONS_URL/$an_id" \
          -X PUT \
          -H 'Content-Type: application/json;charset=utf-8' \
          --data-binary @.notifier.json && echo ''
}

sync_notifiers() {
    # shellcheck disable=SC2043
    for name in PLACE_YOUR_NOTIFIER_NAME_HERE # TODO: parameterise
    do
        an_id=$(get_notifier_id "$name")
        if [[ "$an_id" == "" ]]
        then
            echo >&2 ";; Creating new $name"
            create_notifier "$name"
        else
            echo >&2 ";; Updating $name"
            update_notifier "$name" "$an_id"
        fi
    done
}

update_folder() {
    local uid="${1?Specify json file}"
    local file="${2?Specify json file}"
    echo >&2 ";; Updating folder with uid $uid"
    CURL "$FOLDERS_URL/$uid" \
        -X PUT \
        -H 'Content-Type: application/json;charset=utf-8' \
        --data-binary @"$file" && echo ''
}

create_folder() {
    local uid="${1?Specify uid}"
    local file="${2?Specify json file}"
    echo >&2 ";; Creating folder with uid $uid"
    CURL "$FOLDERS_URL" \
        -X POST \
        -H 'Content-Type: application/json;charset=utf-8' \
        --data-binary @"$file" && echo ''
}

get_folder() {
    local uid="${1?Specify uid}"
    echo >&2 ";; Fetching folder with uid $uid"
    CURL "$FOLDERS_URL/$uid"
}

update_or_create_folder() {
    local uid="${1?Specify uid}"
    yq e -o=json ".[]|select(.uid==\"$uid\")" </dev/null "$FOLDERS_YAML" >.folder.json
    (get_folder "$uid" || echo '') > .existing-folder.json
    if diff <(yq e '{"uid": .uid, "title": .title}' </dev/null .existing-folder.json) \
            <(yq e '{"uid": .uid, "title": .title}' </dev/null .folder.json) \
            >&2
    then
        echo >&2 ";;; No changes found"
    else
        echo >&2 ";;; Changes"
        update_folder "$uid" .folder.json || (echo ";;; Failed" ; create_folder "$uid" .folder.json)
    fi
}

sync_folders() {
    for uid in $(yq e '.[]|.uid' </dev/null "$FOLDERS_YAML")
    do
        update_or_create_folder "$uid"
    done
}
