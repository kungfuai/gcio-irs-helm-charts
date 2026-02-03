{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "worker.environment" -}}
env:
  # AWS Configuration
  - name: AWS_DEFAULT_REGION
    value: {{ .Values.aws.region | quote }}
  - name: S3_BUCKET
    value: {{ required "aws.s3Bucket is required" .Values.aws.s3Bucket | quote }}
  - name: SQS_WORKER_QUEUE_URL
    value: {{ required "aws.sqs.workerQueueURL is required" .Values.aws.sqs.workerQueueURL | quote }}
  - name: SQS_STATUS_QUEUE_URL
    value: {{ required "aws.sqs.statusQueueURL is required" .Values.aws.sqs.statusQueueURL | quote }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}

  # Service URLs
  - name: EXTRACTOR_URL
    value: {{ .Values.services.extractor.url | quote }}
  - name: EXTRACTOR_CONFIG
    value: {{ .Values.worker.extractorConfig | quote }}
  {{- if .Values.worker.extractorCertPath }}
  - name: EXTRACTOR_CERT_PATH
    value: {{ .Values.worker.extractorCertPath | quote }}
  {{- end }}

  # Application
  - name: LOG_LEVEL
    value: {{ .Values.worker.logLevel | default "INFO" | quote }}
  - name: SQS_WORKER_MAX_RETRIES
    value: {{ .Values.worker.sqs.maxRetries | default 5 | quote }}
  - name: SQS_WORKER_MAX_MESSAGES
    value: {{ .Values.worker.sqs.maxMessages | default 10 | quote }}
  - name: SQS_WORKER_MAX_QUEUE_SIZE
    value: {{ .Values.worker.sqs.maxQueueSize | default 1024 | quote }}
  - name: SQS_WORKER_WAIT_SECONDS
    value: {{ .Values.worker.sqs.waitSeconds | default 20 | quote }}
  - name: SQS_NUM_WORKERS
    value: {{ .Values.worker.sqs.numWorkers | default 5 | quote }}

  # Database (from secret)
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "worker.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}

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