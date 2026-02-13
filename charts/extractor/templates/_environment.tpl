{{/*
Facture pods are configured primarily through the environment. Environment variables
are set and defined here using configuration values from the values.yaml file.
*/}}
{{- define "extractor.environment" -}}
env:
  - name: AWS_DEFAULT_REGION
    value: {{ .Values.aws.region | quote }}
  - name: S3_BUCKET
    value: {{ required "aws.s3Bucket is required" .Values.aws.s3Bucket | quote }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}
  # Application
  - name: LOG_LEVEL
    value: {{ .Values.extractor.logLevel | default "INFO" | quote }}
  {{- if .Values.extractor.rfdetrIrsStampStage1Checkpoint }}
  - name: RFDETR_IRS_STAMP_STAGE1_CHECKPOINT
    value: {{ .Values.extractor.rfdetrIrsStampStage1Checkpoint | quote }}
  {{- end }}
  {{- if .Values.extractor.rfdetrIrsStampStage2Checkpoint }}
  - name: RFDETR_IRS_STAMP_STAGE2_CHECKPOINT
    value: {{ .Values.extractor.rfdetrIrsStampStage2Checkpoint | quote }}
  {{- end }}
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "extractor.databaseURLSecretName" . }}
        key: {{ .Values.secrets.databaseURL.key }}
  # Models
  - name: BEDROCK_HAIKU_MODEL
    value: {{ .Values.extractor.models.haiku | quote }}
  - name: BEDROCK_SONNET_MODEL
    value: {{ .Values.extractor.models.sonnet | quote }}
  {{- if .Values.extractor.models.vlmClassifier }}
  - name: VLM_CLASSIFICATION_MODEL
    value: {{ .Values.extractor.models.vlmClassifier | quote }}
  {{- end }}
  {{- if .Values.extractor.models.vlmDateExtractor }}
  - name: VLM_DATE_EXTRACTION_MODEL
    value: {{ .Values.extractor.models.vlmDateExtractor | quote }}
  {{- end }}
  {{- if .Values.extractor.models.parserModel }}
  - name: PARSER_MODEL
    value: {{ .Values.extractor.models.parserModel | quote }}
  {{- end }}
  {{- if .Values.extractor.models.checkModel }}
  - name: CHECK_MODEL
    value: {{ .Values.extractor.models.checkModel | quote }}
  {{- end }}
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
    value: {{ .Values.otel.metricsExporter | default "otlp" | quote }}
  - name: OTEL_LOGS_EXPORTER
    value: "none"
{{- end -}}