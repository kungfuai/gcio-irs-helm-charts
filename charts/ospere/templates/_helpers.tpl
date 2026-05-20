{{/*
Expand the name of the chart.
*/}}
{{- define "ospere.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ospere.fullname" -}}
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
{{- define "ospere.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ospere.labels" -}}
helm.sh/chart: {{ include "ospere.chart" . }}
{{ include "ospere.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ospere.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ospere.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ospere.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Values.serviceAccount.name | default (include "ospere.fullname" .) }}
{{- else -}}
default
{{- end -}}
{{- end -}}

{{- define "ospere.djangoSecretKeySecretName" -}}
{{- if .Values.secrets.create -}}
{{ include "ospere.fullname" . }}
{{- else -}}
{{ default (include "ospere.fullname" .) .Values.secrets.djangoSecretKey.name }}
{{- end -}}
{{- end -}}

{{- define "ospere.postgresPasswordSecretName" -}}
{{- if .Values.secrets.create -}}
{{ include "ospere.fullname" . }}
{{- else -}}
{{ default (include "ospere.fullname" .) .Values.secrets.postgresPassword.name }}
{{- end -}}
{{- end -}}

{{- define "ospere.celeryBrokerURLSecretName" -}}
{{- if .Values.secrets.create -}}
{{ include "ospere.fullname" . }}
{{- else -}}
{{ .Values.secrets.celeryBrokerURL.name }}
{{- end -}}
{{- end -}}

{{- define "ospere.celeryResultBackendSecretName" -}}
{{- if .Values.secrets.create -}}
{{ include "ospere.fullname" . }}
{{- else -}}
{{ .Values.secrets.celeryResultBackend.name }}
{{- end -}}
{{- end -}}

{{- define "ospere.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end -}}
