# grafana-dashboards-provisioning

_Working with dashboards in GUI, storing them in json + yaml, provisioning them to Grafana instance of your choice._

## Running Grafana & Prometheus for viewing / editing your dashboards

A dockerized Grafana & Prometheus services, see [docker-compose.yml](docker-compose.yml), can be started with:

```shell
docker compose up grafana
```

Accessible:

- Grafana on [http://localhost:3000/](http://localhost:3000/)
- Prometheus on [http://localhost:9090/](http://localhost:9090/)

You can add your own service too [docker-compose.yml](docker-compose.yml) and configure _prometheus_ service to scrape it
in [docker-compose/etc/prometheus/prometheus.yml](docker-compose/etc/prometheus/prometheus.yml),
rename `some-service-in-docker-compose:8080` there accordingly.

If you run your service on your host (not in docker), then metrics can be scraped as `host.docker.internal:9095`. See
[docker-compose/etc/prometheus/prometheus.yml](docker-compose/etc/prometheus/prometheus.yml),
again rename `locally-run-service` there to your service name.

### Dashboards

Automatic provisioning of dashboards is configured for docker-compose'd _grafana_ instance.

Dashboards are stored in [docker-compose/var/lib/grafana/dashboards](docker-compose/var/lib/grafana/dashboards).
You can add new or edit existing dashboards via Grafana GUI. If you want to persist changed or newly added dashboards that
you've made via GUI, use [save-dashboards.sh](save-dashboards.sh) script. It will download dashboards and also create a yaml version
for every dashboard.

It is easier to examine diffs of yaml files with [dyff](https://github.com/homeport/dyff) (check it for configuration advices).
Json files are kept for provisioning, please do not modify them. If a modification is needed, do it in yaml and convert it into
json file with:

```shell
yq e -P -o=json '.' lucky-dashboard.yaml
```

#### Shared annotations

Some annotations are the same for all dashboards, they are declared in
[grafana/shared-annotations.jsonnet](grafana/shared-annotations.jsonnet). To splice them into the dashboard code call:

```shell
./save-dashboards.sh with-shared-annotations
```

#### (WIP) Dashboard developing guide

_(In no particular order)_

1. Use uid for notification channels
1. Add descriptions
1. Set tags
1. Change dashboards' uids to something usable in the url

### Misc

#### Unused metrics in your service

There is a [list-unused-metrics.sh](list-unused-metrics.sh) script that checks known metrics against the saved dashboards and shows which metrics
are used and which are not. You need to provide a url to `/metrics` endpoint of a running service.

#### Linter for dashboards

You can copy `check-dashboards-json-2-yaml-consistency` and `check-dashboards` from [.pre-commit-config.yml](.pre-commit-config.yml).

## Provisioning

Below the provisioning of folders, dashboards and notification channels will be described.

All entities, except alert notifications will be checked for differences against currently provisioned versions.
This limitation is because of secret settings which are not readable for alert notifications.

When authentication to Grafana service is using cookies, these steps can be followed to use cookies of your
already authenticated browser session:

1. Open Developer console > Network tab and find any request to your Grafana instance, which has cookies
1. Right-click and select "Copy as cURL"
1. Now run the scripts with `LOAD_CURL_HEADERS_FROM_PB=yes` env var setup

All these steps can be called at once:

```shell
export LOAD_CURL_HEADERS_FROM_PB=yes
export GRAFANA_URL=https://my.grafana.somewhere
pushd grafana/
./provision-folders.sh
./provision-alert-notifications.sh stage
./provision-dashboards.sh stage
popd
```

All scripts dump resource files in current directory. Debugging can be enabled if running with `DEBUG=1` env var.

## Limitations

1. One datasource
1. Only authentication via cookies is supported for now
