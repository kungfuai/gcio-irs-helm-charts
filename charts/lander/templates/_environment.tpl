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
  {{- if .Values.lander.disableIntake }}
  - name: DISABLE_INTAKE
    value: "true"
  {{- end }}

  # OpenTelemetry — configured via Instrumentation CRD (auto-instrumentation)
  # The ADOT operator injects OTEL env vars automatically when the pod annotation
  # instrumentation.opentelemetry.io/inject-python: "true" is present.
  #
  # Custom OTel METRICS need explicit wiring: the operator's default
  # Instrumentation sets OTEL_METRICS_EXPORTER=none, so app counters (LLM
  # token usage) are dropped at the SDK. Operator env injection is append-only
  # — per-pod env set here wins. Points at the CloudWatch agent's OTLP/HTTP
  # receiver (EMF -> CWAgent namespace); requires the agent OTLP receiver
  # from kfai-infra. Harmless if the receiver is absent: export fails and
  # metrics drop, the app is unaffected.
  {{- if .Values.otelMetrics.enabled }}
  - name: OTEL_METRICS_EXPORTER
    value: "otlp"
  - name: OTEL_EXPORTER_OTLP_METRICS_ENDPOINT
    value: {{ .Values.otelMetrics.endpoint | quote }}
  # Delta temporality is required for CloudWatch: the agent converts cumulative
  # streams to deltas and discards each stream's first point as the baseline,
  # which silently swallows low-rate counters (a counter incremented once per
  # pod lifetime never lands). Delta sums export each interval's increments
  # directly; a pod death loses at most the final partial interval.
  - name: OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE
    value: "delta"
  {{- end }}
{{- end -}}