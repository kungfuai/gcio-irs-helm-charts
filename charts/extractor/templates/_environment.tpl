{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "extractor.environment" -}}
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "extractor.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}
{{- end -}}