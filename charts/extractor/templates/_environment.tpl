{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file or K8s secrets.
*/}}
{{- define "extractor.environment" -}}
env:
  - name: DATABASE_URL
    {{- if .Values.extractor.databaseURL }}
    value: {{ .Values.extractor.databaseURL | quote }}
    {{- else }}
    valueFrom:
      secretKeyRef:
        name: facture-db-credentials
        key: database-url
    {{- end }}
{{- end -}}