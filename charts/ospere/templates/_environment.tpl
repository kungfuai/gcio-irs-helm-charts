{{/*
Ospere pods are configured primarily through environment variables.
*/}}
{{- define "ospere.environment" -}}
{{- $celeryBrokerConfigured := or (and .Values.secrets.create .Values.secrets.celeryBrokerURL.value) (and (not .Values.secrets.create) .Values.secrets.celeryBrokerURL.name) -}}
{{- if and .Values.worker.enabled (not $celeryBrokerConfigured) -}}
{{- fail "worker.enabled requires secrets.celeryBrokerURL.value when secrets.create is true, or secrets.celeryBrokerURL.name when secrets.create is false" -}}
{{- end -}}
{{- if and .Values.beat.enabled (not $celeryBrokerConfigured) -}}
{{- fail "beat.enabled requires secrets.celeryBrokerURL.value when secrets.create is true, or secrets.celeryBrokerURL.name when secrets.create is false" -}}
{{- end -}}
env:
  # Django
  - name: DJANGO_SETTINGS_MODULE
    value: {{ .Values.ospere.djangoSettingsModule | quote }}
  - name: DJANGO_DEBUG
    value: {{ .Values.ospere.debug | quote }}
  - name: DJANGO_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "ospere.djangoSecretKeySecretName" . }}
        key: {{ .Values.secrets.djangoSecretKey.key | quote }}
  - name: POSTGRES_DB
    value: {{ .Values.database.name | quote }}
  - name: POSTGRES_USER
    value: {{ .Values.database.user | quote }}
  - name: POSTGRES_HOST
    value: {{ required "database.host is required" .Values.database.host | quote }}
  - name: POSTGRES_PORT
    value: {{ .Values.database.port | quote }}
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ospere.postgresPasswordSecretName" . }}
        key: {{ .Values.secrets.postgresPassword.key | quote }}
  {{- if .Values.ospere.allowedHosts }}
  - name: ALLOWED_HOSTS
    value: {{ .Values.ospere.allowedHosts | quote }}
  {{- end }}
  {{- if .Values.ospere.csrfTrustedOrigins }}
  - name: CSRF_TRUSTED_ORIGINS
    value: {{ .Values.ospere.csrfTrustedOrigins | quote }}
  {{- end }}

  # AWS/S3-compatible storage
  - name: AWS_DEFAULT_REGION
    value: {{ .Values.aws.region | quote }}
  - name: AWS_S3_REGION_NAME
    value: {{ .Values.aws.region | quote }}
  - name: OSPERE_STORAGE_BACKEND
    value: {{ .Values.ospere.storageBackend | quote }}
  - name: OSPERE_LOCAL_STORAGE_ROOT
    value: {{ .Values.ospere.localStorageRoot | quote }}
  - name: OSPERE_ARTIFACTS_BUCKET
    value: {{ required "aws.s3.artifactsBucket is required" .Values.aws.s3.artifactsBucket | quote }}
  - name: OSPERE_SCHEMAS_BUCKET
    value: {{ .Values.aws.s3.schemasBucket | default .Values.aws.s3.artifactsBucket | quote }}
  - name: AWS_QUERYSTRING_EXPIRE
    value: {{ .Values.ospere.awsQuerystringExpire | default 3600 | quote }}
  {{- if .Values.aws.endpointUrl }}
  - name: AWS_S3_ENDPOINT_URL
    value: {{ .Values.aws.endpointUrl | quote }}
  {{- end }}

  # MeF
  - name: MEF_ENVIRONMENT
    value: {{ .Values.ospere.mef.environment | quote }}
  {{- if .Values.ospere.mef.clientSystemIDs }}
  - name: MEF_CLIENT_SYSTEM_IDS
    value: {{ join "," .Values.ospere.mef.clientSystemIDs | quote }}
  {{- else if and .Values.ospere.mef.cert.secretName .Values.ospere.mef.cert.clientSystemIDsKey }}
  - name: MEF_CLIENT_SYSTEM_IDS
    valueFrom:
      secretKeyRef:
        name: {{ .Values.ospere.mef.cert.secretName | quote }}
        key: {{ .Values.ospere.mef.cert.clientSystemIDsKey | quote }}
  {{- end }}
  {{- if .Values.ospere.mef.clientSystemID }}
  - name: MEF_CLIENT_SYSTEM_ID
    value: {{ .Values.ospere.mef.clientSystemID | quote }}
  {{- else if and .Values.ospere.mef.cert.secretName .Values.ospere.mef.cert.clientSystemIDKey }}
  - name: MEF_CLIENT_SYSTEM_ID
    valueFrom:
      secretKeyRef:
        name: {{ .Values.ospere.mef.cert.secretName | quote }}
        key: {{ .Values.ospere.mef.cert.clientSystemIDKey | quote }}
  {{- end }}
  {{- if .Values.ospere.mef.efin }}
  - name: MEF_EFIN
    value: {{ .Values.ospere.mef.efin | quote }}
  {{- end }}
  {{- if .Values.ospere.mef.etin }}
  - name: MEF_ETIN
    value: {{ .Values.ospere.mef.etin | quote }}
  {{- else if and .Values.ospere.mef.cert.secretName .Values.ospere.mef.cert.etinKey }}
  - name: MEF_ETIN
    valueFrom:
      secretKeyRef:
        name: {{ .Values.ospere.mef.cert.secretName | quote }}
        key: {{ .Values.ospere.mef.cert.etinKey | quote }}
  {{- end }}
  {{- if .Values.ospere.mef.softwareID }}
  - name: MEF_SOFTWARE_ID
    value: {{ .Values.ospere.mef.softwareID | quote }}
  {{- end }}
  {{- if .Values.ospere.mef.endpointURL }}
  - name: MEF_ENDPOINT_URL
    value: {{ .Values.ospere.mef.endpointURL | quote }}
  {{- end }}
  - name: MEF_MSI_WSDL
    value: {{ .Values.ospere.mef.msiWSDL | quote }}
  - name: MEF_TRANSMITTER_WSDL
    value: {{ .Values.ospere.mef.transmitterWSDL | quote }}
  {{- if .Values.ospere.mef.cert.secretName }}
  - name: MEF_CERT_PATH
    value: {{ printf "%s/%s" .Values.ospere.mef.cert.mountPath .Values.ospere.mef.cert.certKey | quote }}
  - name: MEF_CERT_KEY_PATH
    value: {{ printf "%s/%s" .Values.ospere.mef.cert.mountPath .Values.ospere.mef.cert.privateKeyKey | quote }}
  {{- end }}

  # Celery
  {{- if $celeryBrokerConfigured }}
  - name: CELERY_BROKER_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "ospere.celeryBrokerURLSecretName" . }}
        key: {{ .Values.secrets.celeryBrokerURL.key | quote }}
  {{- end }}
  {{- if or (and .Values.secrets.create .Values.secrets.celeryResultBackend.value) (and (not .Values.secrets.create) .Values.secrets.celeryResultBackend.name) }}
  - name: CELERY_RESULT_BACKEND
    valueFrom:
      secretKeyRef:
        name: {{ include "ospere.celeryResultBackendSecretName" . }}
        key: {{ .Values.secrets.celeryResultBackend.key | quote }}
  {{- end }}

  # Application
  - name: OSPERE_ENVIRONMENT
    value: {{ .Values.ospere.runtimeEnvironment | default .Release.Namespace | quote }}
  - name: LOG_LEVEL
    value: {{ .Values.ospere.logLevel | default "INFO" | quote }}

  # OpenTelemetry — configured via Instrumentation CRD (auto-instrumentation)
  # The ADOT operator injects OTEL env vars automatically when the pod annotation
  # instrumentation.opentelemetry.io/inject-python: "true" is present.
{{- end -}}

{{/*
Structured logging component label for a specific Ospere workload.
*/}}
{{- define "ospere.serviceComponentEnv" -}}
- name: OSPERE_SERVICE_COMPONENT
  value: {{ .component | quote }}
{{- end -}}
