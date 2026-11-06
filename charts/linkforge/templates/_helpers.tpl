{{/*
Files starting with "_" hold reusable snippets ("named templates") and render nothing by
themselves. Other templates call them with {{ include "name" . }}.
*/}}

{{/* Labels put on every object, so `kubectl get all -l app.kubernetes.io/part-of=linkforge` finds all of ours. */}}
{{- define "linkforge.labels" -}}
app.kubernetes.io/part-of: linkforge
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Pod-level security settings for a given uid. Usage: include "linkforge.podSecurity" 10001 */}}
{{- define "linkforge.podSecurity" -}}
runAsNonRoot: true
runAsUser: {{ . }}
runAsGroup: {{ . }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/* Container-level hardening shared by every container (infra rule: drop ALL caps, read-only fs). */}}
{{- define "linkforge.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}

{{/* IP_HASH_SECRET comes from the same Secret (key IP_HASH_SECRET): it keys the HMAC that replaces
every client IP before a click is stored. Created by hand next to DATABASE_URL, never in git. */}}
{{- define "linkforge.ipHashSecretEnv" -}}
- name: IP_HASH_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: IP_HASH_SECRET
{{- end }}

{{/* DATABASE_URL always comes from the existing Secret, never from values. */}}
{{- define "linkforge.databaseUrlEnv" -}}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: DATABASE_URL
{{- end }}
