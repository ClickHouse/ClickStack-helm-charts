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