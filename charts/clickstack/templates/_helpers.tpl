{{/*
Expand the name of the chart.
*/}}
{{- define "clickstack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "clickstack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Accept the deprecated top-level `hyperdx` values key: overlay it onto `clickstack` (hyperdx wins, and a
null deletes the key as a Helm override would), then alias `hyperdx` to the result so tpl strings that
still read .Values.hyperdx keep working. Every template includes this first; only the first call acts.
*/}}
{{- define "clickstack.normalizeValues" -}}
{{- if not (hasKey .Values "hyperdxKeyUsed") -}}
{{- $legacy := .Values.hyperdx -}}
{{- $_ := set .Values "hyperdxKeyUsed" (kindIs "map" $legacy) -}}
{{- /* --reuse-values from a release made before the rename has hyperdx values but no clickstack defaults. */ -}}
{{- if not (kindIs "map" .Values.clickstack) -}}
{{- $_ = set .Values "clickstack" dict -}}
{{- end -}}
{{- if kindIs "map" $legacy -}}
{{- include "clickstack.overlayValues" (dict "dst" .Values.clickstack "src" $legacy) -}}
{{- end -}}
{{- $_ = set .Values "hyperdx" .Values.clickstack -}}
{{- end -}}
{{- end -}}

{{- define "clickstack.overlayValues" -}}
{{- $dst := .dst -}}
{{- range $key, $value := .src -}}
{{- if kindIs "invalid" $value -}}
{{- $_ := unset $dst $key -}}
{{- else if and (kindIs "map" $value) (kindIs "map" (index $dst $key)) -}}
{{- include "clickstack.overlayValues" (dict "dst" (index $dst $key) "src" $value) -}}
{{- else -}}
{{- $_ := set $dst $key $value -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
HyperDX app resource name. When fullnameOverride is set the user expects full
control over naming, so the -app suffix is omitted. Without the override the
suffix is kept for backward compatibility.
*/}}
{{- define "clickstack.hyperdx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-app" (include "clickstack.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
HyperDX ServiceAccount name. Shared by the Deployment, ServiceAccount, and
dashboard-provisioner RBAC subject so the three can never drift out of sync.
*/}}
{{- define "clickstack.hyperdx.serviceAccountName" -}}
{{- .Values.clickstack.serviceAccount.name | default (include "clickstack.hyperdx.fullname" .) -}}
{{- end -}}

{{/*
Dashboard discovery label. Shared by the inline dashboard ConfigMap (producer)
and the watcher sidecar (consumer) so the selector can't drift between them.
*/}}
{{- define "clickstack.hyperdx.dashboardLabelKey" -}}hyperdx.io/dashboard{{- end -}}
{{- define "clickstack.hyperdx.dashboardLabelValue" -}}true{{- end -}}

{{/*
RBAC rules the dashboard watcher needs: read-only access to ConfigMaps. Shared by
the namespaced Role and the cluster-scoped ClusterRole branches.
*/}}
{{- define "clickstack.hyperdx.dashboardRbacRules" -}}
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["list", "get", "watch"]
{{- end -}}

{{/*
Fail on 1.x and 2.x values that later charts moved or removed. The chart ignores them, so a
user's setting (passwords, replicas, opt-outs) would fall back to the default.
*/}}
{{- define "clickstack.validateRemovedValues" -}}
{{- $removed := dict
  "global.storageClassName" "set storageClassName in the volume claim specs under mongodb.spec, clickhouse.keeper.spec and clickhouse.cluster.spec"
  "global.keepPVC" "remove it; operator-managed PVCs are always kept on uninstall"
  "tasks" "use clickstack.tasks"
  "otel" "configure the otel-collector subchart, and set collector env vars in clickstack.config and clickstack.secrets"
  "hyperdx.apiKey" "use clickstack.secrets.HYPERDX_API_KEY"
  "hyperdx.apiPort" "use clickstack.ports.api"
  "hyperdx.appPort" "use clickstack.ports.app"
  "hyperdx.opampPort" "use clickstack.ports.opamp"
  "hyperdx.appUrl" "use clickstack.config.FRONTEND_URL"
  "hyperdx.frontendUrl" "use clickstack.config.FRONTEND_URL"
  "hyperdx.logLevel" "use clickstack.config.HYPERDX_LOG_LEVEL"
  "hyperdx.usageStatsEnabled" "use clickstack.config.USAGE_STATS_ENABLED (a string, e.g. \"false\")"
  "hyperdx.otelExporterEndpoint" "use clickstack.config.OTEL_EXPORTER_OTLP_ENDPOINT"
  "hyperdx.mongoUri" "use clickstack.config.MONGO_URI"
  "hyperdx.ingress.ingressClassName" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.host" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.path" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.pathType" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.tls" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.proxyBodySize" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.proxyConnectTimeout" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.proxySendTimeout" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.ingress.proxyReadTimeout" "move into clickstack.ingress.spec, and nginx proxy settings into clickstack.ingress.annotations"
  "hyperdx.image" "use clickstack.deployment.image"
  "hyperdx.replicas" "use clickstack.deployment.replicas"
  "hyperdx.livenessProbe" "use clickstack.deployment.livenessProbe"
  "hyperdx.readinessProbe" "use clickstack.deployment.readinessProbe"
  "hyperdx.nodeSelector" "use clickstack.deployment.nodeSelector"
  "hyperdx.tolerations" "use clickstack.deployment.tolerations"
  "hyperdx.annotations" "use clickstack.deployment.annotations"
  "hyperdx.labels" "use clickstack.deployment.labels"
  "hyperdx.env" "use clickstack.deployment.env"
  "hyperdx.waitForMongodb" "use clickstack.deployment.waitForMongodb"
  "hyperdx.useExistingConfigSecret" "use clickstack.deployment.useExistingConfigSecret"
  "hyperdx.existingConfigSecret" "use clickstack.deployment.existingConfigSecret"
  "hyperdx.existingConfigConnectionsKey" "use clickstack.deployment.existingConfigConnectionsKey"
  "hyperdx.existingConfigSourcesKey" "use clickstack.deployment.existingConfigSourcesKey"
  "hyperdx.defaultConnections" "use clickstack.deployment.defaultConnections"
  "hyperdx.defaultSources" "use clickstack.deployment.defaultSources"
  "mongodb.password" "use clickstack.secrets.MONGODB_PASSWORD"
  "mongodb.image" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.port" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.strategy" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.nodeSelector" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.tolerations" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.persistence" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.livenessProbe" "configure the MongoDBCommunity resource under mongodb.spec"
  "mongodb.readinessProbe" "configure the MongoDBCommunity resource under mongodb.spec"
  "clickhouse.prometheus.endpoint" "remove it; only clickhouse.prometheus.port is read"
  "clickhouse.config" "set ClickHouse credentials in clickstack.secrets (CLICKHOUSE_PASSWORD, CLICKHOUSE_APP_PASSWORD)"
  "clickhouse.image" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.terminationGracePeriodSeconds" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.resources" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.livenessProbe" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.readinessProbe" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.startupProbe" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.nodeSelector" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.tolerations" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.service" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
  "clickhouse.persistence" "configure the ClickHouseCluster resource under clickhouse.cluster.spec"
-}}
{{- $found := list -}}
{{- range $path := keys $removed | sortAlpha -}}
{{- $node := $.Values -}}
{{- range $key := splitList "." $path -}}
{{- $node = index (ternary $node (dict) (kindIs "map" $node)) $key -}}
{{- end -}}
{{- /* A null value is how users clear a key, so it counts as unset. */ -}}
{{- if not (kindIs "invalid" $node) -}}
{{- $found = append $found (printf "%s: %s" $path (index $removed $path)) -}}
{{- end -}}
{{- end -}}
{{- if $found -}}
{{- fail (printf "these values from chart 1.x or 2.x are no longer read, see docs/UPGRADE.md:\n- %s" (join "\n- " $found)) -}}
{{- end -}}
{{- end -}}

{{/*
Fail fast on invalid dashboards input instead of surfacing Go template panics or
API-server rejections: unusable ServiceAccount config, a non-list or ill-typed
namespaces value, the contradictory ALL-plus-named-namespaces scope, an empty scope
or unwatched inline dashboards when the release namespace is excluded, malformed
configMaps entries, and volume/mount names that collide with the provisioner's.
*/}}
{{- define "clickstack.hyperdx.validateDashboards" -}}
{{- $dashboards := default (dict) .Values.clickstack.dashboards -}}
{{- if $dashboards.enabled -}}
{{- if and (not .Values.clickstack.serviceAccount.create) (not .Values.clickstack.serviceAccount.name) -}}
{{- fail "clickstack.dashboards: the dashboard watcher needs a ServiceAccount to bind RBAC to; set clickstack.serviceAccount.create=true or provide clickstack.serviceAccount.name" -}}
{{- end -}}
{{- $namespaces := default (list) $dashboards.namespaces -}}
{{- if not (kindIs "slice" $namespaces) -}}
{{- fail "clickstack.dashboards.namespaces: must be a list of namespace names" -}}
{{- end -}}
{{- range $namespaces -}}
{{- if not (kindIs "string" .) -}}
{{- fail "clickstack.dashboards.namespaces: entries must be quoted strings" -}}
{{- end -}}
{{- end -}}
{{- if and (ne (include "clickstack.hyperdx.dashboardsIncludeReleaseNamespace" .) "true") (not $namespaces) -}}
{{- fail "clickstack.dashboards.includeReleaseNamespace: false requires at least one entry in clickstack.dashboards.namespaces (otherwise the watcher has nothing to watch)" -}}
{{- end -}}
{{- if and $dashboards.configMaps (ne (include "clickstack.hyperdx.dashboardsClusterWide" .) "true") (not (has .Release.Namespace (include "clickstack.hyperdx.effectiveNamespaces" . | splitList ","))) -}}
{{- fail "clickstack.dashboards.configMaps: inline dashboards are created in the release namespace, which includeReleaseNamespace: false excludes from discovery; list the release namespace in clickstack.dashboards.namespaces or ship the dashboards as labeled ConfigMaps in a watched namespace" -}}
{{- end -}}
{{- if and (eq (include "clickstack.hyperdx.dashboardsClusterWide" .) "true") (gt (len $namespaces) 1) -}}
{{- fail "clickstack.dashboards.namespaces: \"ALL\" cannot be combined with specific namespaces (it already grants cluster-wide discovery)" -}}
{{- end -}}
{{- range $namespaces -}}
{{- if not (trim .) -}}
{{- fail "clickstack.dashboards.namespaces: entries must be non-empty namespace names" -}}
{{- end -}}
{{- if and (ne . "ALL") (eq (upper (trim .)) "ALL") -}}
{{- fail "clickstack.dashboards.namespaces: use exactly \"ALL\" (uppercase, no surrounding spaces) for cluster-wide discovery" -}}
{{- end -}}
{{- if and (ne . "ALL") (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" (trim .))) -}}
{{- fail "clickstack.dashboards.namespaces: entries must be valid DNS-1123 labels (lowercase alphanumeric and '-')" -}}
{{- end -}}
{{- end -}}
{{- range $key, $value := (default (dict) $dashboards.configMaps) -}}
{{- if not (kindIs "string" $value) -}}
{{- fail (printf "clickstack.dashboards.configMaps[%s]: value must be a JSON string — use a YAML block scalar (|)" $key) -}}
{{- end -}}
{{- if not (regexMatch "^[A-Za-z0-9][A-Za-z0-9._-]*\\.json$" $key) -}}
{{- fail (printf "clickstack.dashboards.configMaps: key %q must be a valid ConfigMap key ending in .json (the provisioner only reads *.json files)" $key) -}}
{{- end -}}
{{- end -}}
{{- range (default (list) .Values.clickstack.deployment.volumes) -}}
{{- if eq (get . "name") "dashboards" -}}
{{- fail "clickstack.deployment.volumes: the name \"dashboards\" is reserved by the dashboard provisioner" -}}
{{- end -}}
{{- end -}}
{{- range (default (list) .Values.clickstack.deployment.volumeMounts) -}}
{{- if or (eq (get . "name") "dashboards") (eq (get . "mountPath") "/dashboards") -}}
{{- fail "clickstack.deployment.volumeMounts: the name \"dashboards\" and mountPath \"/dashboards\" are reserved by the dashboard provisioner" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Namespaces the watcher discovers in for the non-ALL scope: the release namespace
(unless includeReleaseNamespace is false) plus any configured extras, deduped and
comma-joined. Single source for both the watcher NAMESPACE env and the per-namespace
RBAC objects so watch scope and granted scope can't drift.
*/}}
{{- define "clickstack.hyperdx.effectiveNamespaces" -}}
{{- $raw := default (list) (default (dict) .Values.clickstack.dashboards).namespaces -}}
{{- $namespaces := ternary $raw (list) (kindIs "slice" $raw) -}}
{{- $base := ternary (list .Release.Namespace) (list) (eq (include "clickstack.hyperdx.dashboardsIncludeReleaseNamespace" .) "true") -}}
{{- $trimmed := list -}}
{{- range (concat $base $namespaces) -}}
{{- $trimmed = append $trimmed (trim (toString .)) -}}
{{- end -}}
{{- $trimmed | uniq | join "," -}}
{{- end -}}

{{/*
Whether dashboard discovery is cluster-wide (the ALL sentinel). Single source for the
Role-vs-ClusterRole choice in the RBAC template and the watcher NAMESPACE env in the
Deployment, so the granted scope and the watched scope can't diverge. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsClusterWide" -}}
{{- $namespaces := default (list) (default (dict) .Values.clickstack.dashboards).namespaces -}}
{{- if and (kindIs "slice" $namespaces) (has "ALL" $namespaces) }}true{{- end -}}
{{- end -}}

{{/*
Whether discovery spans the release namespace plus at least one other namespace.
Selects the scoped ClusterRole + per-namespace RoleBinding path over namespaced
Roles. An effective set without the release namespace (includeReleaseNamespace:
false) gets a namespaced Role + RoleBinding in each target namespace instead, so
nothing is granted in the release namespace and no cluster-scoped object is
created. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsCrossNamespace" -}}
{{- $effective := include "clickstack.hyperdx.effectiveNamespaces" . | splitList "," -}}
{{- if and (gt (len $effective) 1) (has .Release.Namespace $effective) }}true{{- end -}}
{{- end -}}

{{/*
Whether the release namespace is part of the watcher's discovery scope. A missing
key (e.g. an upgrade with --reuse-values from a chart version without it) keeps the
chart default of true. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsIncludeReleaseNamespace" -}}
{{- $dashboards := default (dict) .Values.clickstack.dashboards -}}
{{- if or (not (hasKey $dashboards "includeReleaseNamespace")) $dashboards.includeReleaseNamespace }}true{{- end -}}
{{- end -}}

{{/*
Whether the collector is managed over OpAMP. A missing key (e.g. an upgrade with
--reuse-values from a chart version without it) keeps the chart default of true.
Renders "true" or "".
*/}}
{{- define "clickstack.opampEnabled" -}}
{{- $opamp := default (dict) .Values.clickstack.opamp -}}
{{- if or (not (hasKey $opamp "enabled")) $opamp.enabled }}true{{- end -}}
{{- end -}}

{{/*
Whether the chart creates the watcher's RBAC. Missing rbac subtree (e.g. an upgrade
with --reuse-values that only sets dashboards.enabled) keeps the chart default of
true rather than silently deploying a watcher with no read access. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsRbacCreate" -}}
{{- $rbac := default (dict) (default (dict) .Values.clickstack.dashboards).rbac -}}
{{- if or (not (hasKey $rbac "create")) $rbac.create }}true{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "clickstack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickstack.labels" -}}
helm.sh/chart: {{ include "clickstack.chart" . }}
{{ include "clickstack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickstack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickstack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MongoDB CR name
*/}}
{{- define "clickstack.mongodb.fullname" -}}
{{- printf "%s-mongodb" (include "clickstack.fullname" .) -}}
{{- end }}

{{/*
MongoDB headless service name (created by the MCK operator as {cr-name}-svc)
*/}}
{{- define "clickstack.mongodb.svc" -}}
{{- printf "%s-svc" (include "clickstack.mongodb.fullname" .) -}}
{{- end }}

{{/*
OTEL Collector fullname (matches subchart with alias otel-collector)
*/}}
{{- define "clickstack.otel.fullname" -}}
{{- printf "%s-otel-collector" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
ClickHouse cluster CR name
*/}}
{{- define "clickstack.clickhouse.fullname" -}}
{{- printf "%s-clickhouse" (include "clickstack.fullname" .) -}}
{{- end }}

{{/*
ClickHouse Keeper CR name
*/}}
{{- define "clickstack.clickhouse.keeper" -}}
{{- printf "%s-keeper" (include "clickstack.fullname" .) -}}
{{- end }}

{{/*
ClickHouse headless service name. The operator creates a headless service named {CR}-clickhouse-headless.
*/}}
{{- define "clickstack.clickhouse.svc" -}}
{{- printf "%s-clickhouse-headless" (include "clickstack.clickhouse.fullname" .) -}}
{{- end }}

{{/*
Whether the ClickHouse PromQL config is injected into the ClickHouseCluster CR.
Needs clickstack.promql.enabled and a ClickHouse server image of 26.6 or newer, the
first release with the prometheus_api_v1 handler. The tag is read from
clickhouse.cluster.spec.containerTemplate.image.tag; a four-part ClickHouse version
and an image-variant suffix such as "-alpine" are reduced to semver first. A tag
that carries no version (e.g. "latest") is assumed new enough. Renders "true" or "".
*/}}
{{- define "clickstack.clickhouse.promqlEnabled" -}}
{{- if .Values.clickstack.promql.enabled -}}
{{- $tag := toString (dig "containerTemplate" "image" "tag" "" .Values.clickhouse.cluster.spec) -}}
{{- $version := regexFind "^[0-9]+\\.[0-9]+(\\.[0-9]+)?" $tag -}}
{{- if or (not $version) (semverCompare ">= 26.6" $version) }}true{{- end -}}
{{- end -}}
{{- end }}

{{/*
ClickHouse settings that back PromQL, merged under the user's
clickhouse.cluster.spec.settings by clickhouse/cluster.yaml. Mirrors the upstream
ClickStack config.xml/users.xml: Prometheus remote write/read into the TimeSeries
table the otel-collector creates, the Prometheus HTTP API on the main HTTP port, and
the experimental setting the TimeSeries engine needs. The metrics handler is
repeated because ClickHouse ignores its legacy prometheus.endpoint settings once a
handlers block exists.
*/}}
{{- define "clickstack.clickhouse.promqlSettings" -}}
{{- $database := .Values.clickstack.config.HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE | default "default" }}
extraConfig:
  prometheus:
    handlers:
      metrics_handler:
        url: /metrics
        handler:
          type: expose_metrics
          metrics: true
          asynchronous_metrics: true
          events: true
          errors: true
      remote_write_handler:
        url: /write
        handler:
          type: remote_write
          database: {{ $database | quote }}
          table: metrics_ts
      remote_read_handler:
        url: /read
        handler:
          type: remote_read
          database: {{ $database | quote }}
          table: metrics_ts
  http_handlers:
    rule:
      url_prefix: /prometheus/api/v1
      handler:
        type: prometheus_api_v1
    defaults: ""
extraUsersConfig:
  profiles:
    default:
      allow_experimental_time_series_table: 1
{{- end }}

{{/*
Render the chart-managed HyperDX ConfigMap from one canonical template so the
manifest and the Deployment rollout checksum cannot drift.
*/}}
{{- define "clickstack.hyperdx.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: clickstack-config
  labels:
    {{- include "clickstack.labels" . | nindent 4 }}
data:
  {{- range $k, $v := .Values.clickstack.config }}
  {{ $k }}: {{ tpl (toString $v) $ | quote }}
  {{- end }}
  {{- if and .Values.global.otelCollector.customConfig (not (hasKey .Values.clickstack.config "CUSTOM_OTELCOL_CONFIG_FILE")) }}
  CUSTOM_OTELCOL_CONFIG_FILE: "/etc/otelcol-contrib/custom/custom.config.yaml"
  {{- end }}
{{- end }}

{{/*
Render the chart-managed HyperDX Secret from one canonical template so the
manifest and the Deployment rollout checksum cannot drift.
*/}}
{{- define "clickstack.hyperdx.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: clickstack-secret
  labels:
    {{- include "clickstack.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- range $k, $v := .Values.clickstack.secrets }}
  {{ $k }}: {{ tpl (toString $v) $ | quote }}
  {{- end }}
{{- end }}
