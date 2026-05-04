{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "worker.environment" -}}
{{- $notifier := .Values.worker.notifier -}}
{{- $notifierURLCount := list $notifier.transcriptionURL $notifier.acknowledgementURL $notifier.issueURL | compact | len -}}
{{- if and $notifier.enabled (eq $notifierURLCount 0) -}}
{{- fail "worker.notifier.enabled requires at least one notifier URL" -}}
{{- end -}}
{{- if and $notifier.enabled (not .Values.secrets.notifierApiKey.name) -}}
{{- fail "worker.notifier.enabled requires secrets.notifierApiKey.name" -}}
{{- end -}}
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
    value: {{ .Values.worker.sqs.maxRetries | default 3 | quote }}
  - name: SQS_WORKER_MAX_MESSAGES
    value: {{ .Values.worker.sqs.maxMessages | default 1 | quote }}
  - name: SQS_WORKER_MAX_QUEUE_SIZE
    value: {{ .Values.worker.sqs.maxQueueSize | default 16 | quote }}
  - name: SQS_WORKER_WAIT_SECONDS
    value: {{ .Values.worker.sqs.waitSeconds | default 30 | quote }}
  - name: SQS_NUM_WORKERS
    value: {{ .Values.worker.sqs.numWorkers | default 1 | quote }}

  # GovCIO completion/status notifier
  - name: NOTIFIER_ENABLED
    value: {{ $notifier.enabled | quote }}
  - name: NOTIFIER_DRAIN_QUEUE
    value: {{ $notifier.drainQueue | quote }}
  - name: NOTIFIER_TIMEOUT
    value: {{ $notifier.timeout | default 30 | quote }}
  - name: NOTIFIER_RETRIES
    value: {{ $notifier.retries | default 3 | quote }}
  {{- if $notifier.transcriptionURL }}
  - name: NOTIFIER_TRANSCRIPTION_URL
    value: {{ $notifier.transcriptionURL | quote }}
  {{- end }}
  {{- if $notifier.acknowledgementURL }}
  - name: NOTIFIER_ACKNOWLEDGEMENT_URL
    value: {{ $notifier.acknowledgementURL | quote }}
  {{- end }}
  {{- if $notifier.issueURL }}
  - name: NOTIFIER_ISSUE_URL
    value: {{ $notifier.issueURL | quote }}
  {{- end }}
  {{- if .Values.secrets.notifierApiKey.name }}
  - name: NOTIFIER_API_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.secrets.notifierApiKey.name | quote }}
        key: {{ .Values.secrets.notifierApiKey.key | quote }}
  {{- end }}

  # Database (from secret)
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "worker.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}

  # OpenTelemetry — configured via Instrumentation CRD (auto-instrumentation)
  # The ADOT operator injects OTEL env vars automatically when the pod annotation
  # instrumentation.opentelemetry.io/inject-python: "true" is present.
{{- end -}}
