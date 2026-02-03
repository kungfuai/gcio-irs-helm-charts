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
    value: {{ required "aws.s3.cacheBucket is required" .Values.aws.s3.cacheBucket | quote }}
  - name: S3_SOURCE_BUCKET
    value: {{ required "aws.s3.sourceBucket is required" .Values.aws.s3.sourceBucket | quote }}
  - name: SQS_WORKER_QUEUE_URL
    value: {{ required "aws.sqs.workerQueueURL is required" .Values.aws.sqs.workerQueueURL | quote }}
  - name: SQS_STATUS_QUEUE_URL
    value: {{ required "aws.sqs.statusQueueURL is required" .Values.aws.sqs.statusQueueURL | quote }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}

  # Service URLs
  - name: WORKER_URL
    value: {{ .Values.services.worker.url | quote }}

  # Database (from secret)
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "lander.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}

  # Application
  - name: LOG_LEVEL
    value: {{ .Values.lander.logLevel | default "INFO" | quote }}
  - name: ENABLE_PROCESS_ENDPOINT
    value: {{ .Values.lander.enableProcessEndpoint | default false | quote }}

  # OpenTelemetry
  - name: OTEL_SERVICE_NAME
    value: {{ .Chart.Name | quote }}
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: {{ .Values.otel.endpoint | default "cloudwatch-agent.amazon-cloudwatch:4315" | quote }}
  - name: OTEL_EXPORTER_OTLP_INSECURE
    value: "true"
  - name: OTEL_TRACES_EXPORTER
    value: "otlp"
  - name: OTEL_METRICS_EXPORTER
    value: "none"
  - name: OTEL_LOGS_EXPORTER
    value: "none"
{{- end -}}