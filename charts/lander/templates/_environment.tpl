{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file or K8s secrets.
*/}}
{{- define "lander.environment" -}}
env:
  - name: DATABASE_URL
    {{- if .Values.lander.databaseURL }}
    value: {{ .Values.lander.databaseURL | quote }}
    {{- else }}
    valueFrom:
      secretKeyRef:
        name: facture-db-credentials
        key: database-url
    {{- end }}
{{- end -}}