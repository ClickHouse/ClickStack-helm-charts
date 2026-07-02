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
{{- .Values.hyperdx.serviceAccount.name | default (include "clickstack.hyperdx.fullname" .) -}}
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
Reject contradictory discovery scope. The "ALL" sentinel already grants cluster-wide
discovery, so combining it with named namespaces would silently escalate to cluster
scope — fail fast instead of granting more than the operator likely intended.
*/}}
{{- define "clickstack.hyperdx.validateDashboards" -}}
{{- if .Values.hyperdx.dashboards.enabled -}}
{{- $namespaces := .Values.hyperdx.dashboards.namespaces -}}
{{- if and (eq (include "clickstack.hyperdx.dashboardsClusterWide" .) "true") (gt (len $namespaces) 1) -}}
{{- fail "hyperdx.dashboards.namespaces: \"ALL\" cannot be combined with specific namespaces (it already grants cluster-wide discovery)" -}}
{{- end -}}
{{- range $namespaces -}}
{{- if not (trim .) -}}
{{- fail "hyperdx.dashboards.namespaces: entries must be non-empty namespace names" -}}
{{- end -}}
{{- if and (ne . "ALL") (eq (upper (trim .)) "ALL") -}}
{{- fail "hyperdx.dashboards.namespaces: use exactly \"ALL\" (uppercase, no surrounding spaces) for cluster-wide discovery" -}}
{{- end -}}
{{- if and (ne . "ALL") (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" (trim .))) -}}
{{- fail "hyperdx.dashboards.namespaces: entries must be valid DNS-1123 labels (lowercase alphanumeric and '-')" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Namespaces the watcher discovers in for the non-ALL scope: the release namespace
plus any configured extras, deduped and comma-joined. Single source for both the
watcher NAMESPACE env and the per-namespace RoleBindings so watch scope and granted
scope can't drift.
*/}}
{{- define "clickstack.hyperdx.effectiveNamespaces" -}}
{{- $trimmed := list -}}
{{- range (concat (list .Release.Namespace) .Values.hyperdx.dashboards.namespaces) -}}
{{- $trimmed = append $trimmed (trim .) -}}
{{- end -}}
{{- $trimmed | uniq | join "," -}}
{{- end -}}

{{/*
Whether dashboard discovery is cluster-wide (the ALL sentinel). Single source for the
Role-vs-ClusterRole choice in the RBAC template and the watcher NAMESPACE env in the
Deployment, so the granted scope and the watched scope can't diverge. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsClusterWide" -}}
{{- if has "ALL" .Values.hyperdx.dashboards.namespaces }}true{{- end -}}
{{- end -}}

{{/*
Whether discovery spans more than one namespace (the effective, deduped set is larger
than just the release namespace). Selects the scoped ClusterRole + per-namespace
RoleBinding path over a plain namespaced Role. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.dashboardsCrossNamespace" -}}
{{- if gt (len (include "clickstack.hyperdx.effectiveNamespaces" . | splitList ",")) 1 }}true{{- end -}}
{{- end -}}

{{/*
Whether this chart creates the HyperDX ServiceAccount: when explicitly requested, or when
dashboards need one and no external name is supplied. Shared by the ServiceAccount template
and the Deployment's serviceAccountName guard so the "the named SA must exist" invariant
can't drift between them. Renders "true" or "".
*/}}
{{- define "clickstack.hyperdx.createServiceAccount" -}}
{{- if or .Values.hyperdx.serviceAccount.create (and .Values.hyperdx.dashboards.enabled (not .Values.hyperdx.serviceAccount.name)) }}true{{- end -}}
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