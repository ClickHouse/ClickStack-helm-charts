{{/*
Expand the name of the chart.
*/}}
{{- define "hdx-oss.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "hdx-oss.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "hdx-oss.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hdx-oss.labels" -}}
helm.sh/chart: {{ include "hdx-oss.chart" . }}
{{ include "hdx-oss.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hyperdx
{{- if .Values.global.additionalLabels}}
{{ toYaml .Values.global.additionalLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hdx-oss.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hdx-oss.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Hyperdx component
*/}}
{{- define "hdx-oss.hyperdx.labels" -}}
app.kubernetes.io/component: hyperdx
{{- end }}

{{/*
Hyperdx component
*/}}
{{- define "hdx-oss.clickhouse.labels" -}}
app.kubernetes.io/component: clickhouse
{{- end }}

{{/*
MongoDB component
*/}}
{{- define "hdx-oss.mongodb.labels" -}}
app.kubernetes.io/component: mongo
{{- end }}

{{/*
OpenTelemetry Collector component
*/}}
{{- define "hdx-oss.otel.labels" -}}
app.kubernetes.io/component: opentelemetry
{{- end }}
