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
{{- if and $notifier.enabled (not $notifier.clientID) -}}
{{- fail "worker.notifier.enabled requires worker.notifier.clientID" -}}
{{- end -}}
{{- if and $notifier.enabled (not .Values.secrets.notifierClientSecret.name) -}}
{{- fail "worker.notifier.enabled requires secrets.notifierClientSecret.name" -}}
{{- end -}}
env:
  # AWS Configuration
  - name: AWS_DEFAULT_REGION
    value: {{ .Values.aws.region | quote }}
  - name: S3_BUCKET
    value: {{ required "aws.s3Bucket is required" .Values.aws.s3Bucket | quote }}
  {{- if .Values.aws.s3SyntheticDataBucket }}
  - name: S3_SYNTHETIC_DATA_BUCKET
    value: {{ .Values.aws.s3SyntheticDataBucket | quote }}
  {{- end }}
  - name: SQS_WORKER_QUEUE_URL
    value: {{ required "aws.sqs.workerQueueURL is required" .Values.aws.sqs.workerQueueURL | quote }}
  - name: SQS_STATUS_QUEUE_URL
    value: {{ required "aws.sqs.statusQueueURL is required" .Values.aws.sqs.statusQueueURL | quote }}
  {{- if .Values.aws.sqs.resumeQueueURL }}
  # Optional high-priority queue for resumed (e.g. completed Bedrock batch)
  # documents. Workers poll it before the main worker queue when set.
  - name: SQS_WORKER_RESUME_QUEUE_URL
    value: {{ .Values.aws.sqs.resumeQueueURL | quote }}
  {{- end }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}

  # Service URLs
  - name: EXTRACTOR_URL
    value: {{ .Values.services.extractor.url | quote }}
  - name: EXTRACTOR_CONFIG
    value: {{ .Values.worker.extractorConfig | quote }}
  {{- if .Values.worker.parseRecipe }}
  - name: PARSE_RECIPE
    value: {{ .Values.worker.parseRecipe | quote }}
  {{- end }}
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
  {{- if $notifier.wireMonikers }}
  - name: NOTIFIER_WIRE_MONIKERS
    value: {{ $notifier.wireMonikers | toJson | quote }}
  {{- end }}
  {{- if $notifier.clientID }}
  - name: NOTIFIER_CLIENT_ID
    value: {{ $notifier.clientID | quote }}
  {{- end }}
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
  {{- if .Values.secrets.notifierClientSecret.name }}
  - name: NOTIFIER_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: {{ .Values.secrets.notifierClientSecret.name | quote }}
        key: {{ .Values.secrets.notifierClientSecret.key | quote }}
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

{{/*
Extra environment for the Bedrock batch coordinator deployments (classify/parse).
These run the SAME worker image with a different subcommand and reuse the worker
env block above (AWS/S3/SQS/DB). This partial only adds the BEDROCK_BATCH_* knobs
that the `python -m worker bedrock-batch-*` entrypoints read as argument defaults.

Emitted as bare list items (no `env:` header) so it can be appended after
`worker.environment` at the same indentation, mirroring the ospere pattern.

Call with: (dict "ctx" . "component" "classify"|"parse")
*/}}
{{- define "worker.bedrockBatchEnv" -}}
{{- $ctx := .ctx -}}
{{- $component := .component -}}
{{- $b := $ctx.Values.bedrockBatch -}}
{{- $comp := index $b $component | default dict -}}
- name: BEDROCK_BATCH_ROLE_ARN
  value: {{ required "bedrockBatch.roleArn is required when a coordinator is enabled" $b.roleArn | quote }}
{{- if $b.bucket }}
- name: BEDROCK_BATCH_BUCKET
  value: {{ $b.bucket | quote }}
{{- end }}
{{- with ($comp.modelId | default $b.modelId) }}
- name: BEDROCK_BATCH_MODEL_ID
  value: {{ . | quote }}
{{- end }}
- name: BEDROCK_BATCH_MIN_RECORDS
  value: {{ $b.minRecords | quote }}
- name: BEDROCK_BATCH_MAX_WAIT_SECONDS
  value: {{ $b.maxWaitSeconds | quote }}
# under-minimum policy — see the long note in values.yaml (bedrockBatch.underMinimumPolicy).
- name: BEDROCK_BATCH_UNDER_MINIMUM_POLICY
  value: {{ $b.underMinimumPolicy | quote }}
{{- if eq $component "classify" }}
- name: BEDROCK_BATCH_CLASSIFY_MAX_RECORDS
  value: {{ ($comp.maxRecords | default $b.maxRecords) | quote }}
- name: BEDROCK_BATCH_CLASSIFY_INTERVAL_SECONDS
  value: {{ ($comp.intervalSeconds | default $b.intervalSeconds) | quote }}
{{- else if eq $component "parse" }}
- name: BEDROCK_BATCH_PARSE_MAX_RECORDS
  value: {{ ($comp.maxRecords | default $b.maxRecords) | quote }}
- name: BEDROCK_BATCH_PARSE_INTERVAL_SECONDS
  value: {{ ($comp.intervalSeconds | default $b.intervalSeconds) | quote }}
{{- if $comp.modelId }}
- name: BEDROCK_BATCH_PARSE_MODEL_ID
  value: {{ $comp.modelId | quote }}
{{- end }}
{{- end }}
{{- end -}}
