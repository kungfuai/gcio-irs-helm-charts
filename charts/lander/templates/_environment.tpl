{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "lander.environment" -}}
env:
  # AWS Configuration
  - name: AWS_DEFAULT_REGION
    value: {{ .Values.aws.region | quote }}
  - name: S3_BUCKET
    value: {{ required "aws.s3Bucket is required" .Values.aws.s3Bucket | quote }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}

  # Service URLs
  - name: WORKER_URL
    value: {{ .Values.services.worker.url | quote }}
  - name: EXTRACTOR_URL
    value: {{ .Values.services.extractor.url | quote }}

  # Database (from secret)
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "lander.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}
{{- end -}}