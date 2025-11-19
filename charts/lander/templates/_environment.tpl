{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "lander.environment" -}}
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "lander.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}
{{- end -}}