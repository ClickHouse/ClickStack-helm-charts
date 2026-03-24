# Additional Manifests

The `additionalManifests` value lets you deploy arbitrary Kubernetes objects alongside the ClickStack chart. Use it to add resources that the chart does not template natively -- NetworkPolicy, HorizontalPodAutoscaler, ServiceAccount, PodMonitor, custom Ingress controllers, or any other Kubernetes API object.

## How it works

Each entry in `additionalManifests` is a complete Kubernetes resource definition. The chart iterates over the list, converts each entry to YAML, and passes it through Helm's `tpl` function. This means you can use any Helm template expression inside string values:

- `.Release.Name`, `.Release.Namespace`
- `include "clickstack.fullname" .` and other chart helpers
- `.Values.*` references

```yaml
# values.yaml
additionalManifests:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: '{{ include "clickstack.fullname" . }}-custom'
    data:
      release: '{{ .Release.Name }}'
```

> **Important:** Template expressions inside values must be quoted as YAML strings
> (wrap them in single quotes). Unquoted `{{` is invalid YAML.

## Available chart helpers

These helpers are defined in `templates/_helpers.tpl` and can be used inside `additionalManifests` entries:

| Helper | Description | Example output |
|--------|-------------|----------------|
| `clickstack.name` | Chart name (truncated to 63 chars) | `clickstack` |
| `clickstack.fullname` | Release-qualified name | `my-release-clickstack` |
| `clickstack.chart` | Chart name + version | `clickstack-2.0.0` |
| `clickstack.labels` | Standard Helm labels block | *(multi-line)* |
| `clickstack.selectorLabels` | `app.kubernetes.io/name` + `instance` | *(multi-line)* |
| `clickstack.mongodb.fullname` | MongoDB CR name | `my-release-clickstack-mongodb` |
| `clickstack.clickhouse.fullname` | ClickHouse CR name | `my-release-clickstack-clickhouse` |
| `clickstack.otel.fullname` | OTEL Collector name | `my-release-otel-collector` |

## Examples

### ServiceAccount

```yaml
additionalManifests:
  - apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: '{{ include "clickstack.fullname" . }}'
      namespace: '{{ .Release.Namespace }}'
      labels:
        {{- include "clickstack.labels" . | nindent 8 }}
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789:role/my-role"
```

### NetworkPolicy

Restrict ingress traffic to the HyperDX pods:

```yaml
additionalManifests:
  - apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: '{{ include "clickstack.fullname" . }}-allow-ingress'
    spec:
      podSelector:
        matchLabels:
          {{- include "clickstack.selectorLabels" . | nindent 10 }}
      policyTypes:
        - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: ingress-nginx
          ports:
            - protocol: TCP
              port: {{ .Values.hyperdx.ports.app }}
            - protocol: TCP
              port: {{ .Values.hyperdx.ports.api }}
```

### HorizontalPodAutoscaler

```yaml
additionalManifests:
  - apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: '{{ include "clickstack.fullname" . }}-hpa'
    spec:
      scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: '{{ include "clickstack.fullname" . }}-app'
      minReplicas: 2
      maxReplicas: 10
      metrics:
        - type: Resource
          resource:
            name: cpu
            target:
              type: Utilization
              averageUtilization: 75
```

### PodMonitor (Prometheus Operator)

```yaml
additionalManifests:
  - apiVersion: monitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: '{{ include "clickstack.fullname" . }}'
      labels:
        {{- include "clickstack.labels" . | nindent 8 }}
    spec:
      selector:
        matchLabels:
          {{- include "clickstack.selectorLabels" . | nindent 10 }}
      podMetricsEndpoints:
        - port: metrics
          interval: 30s
```

### AWS ALB Ingress

When using the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/), disable the chart's built-in nginx-centric Ingress and define a fully custom one:

```yaml
hyperdx:
  ingress:
    enabled: false   # disable the built-in nginx Ingress

additionalManifests:
  - apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: '{{ include "clickstack.fullname" . }}-alb'
      labels:
        {{- include "clickstack.labels" . | nindent 8 }}
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789:certificate/abc-123"
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
        alb.ingress.kubernetes.io/ssl-redirect: "443"
        alb.ingress.kubernetes.io/group.name: clickstack
        alb.ingress.kubernetes.io/healthcheck-path: /api/health
        alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
        alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
        alb.ingress.kubernetes.io/healthy-threshold-count: "2"
        alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"
    spec:
      ingressClassName: alb
      rules:
        - host: clickstack.example.com
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: '{{ include "clickstack.fullname" . }}-app'
                    port:
                      number: {{ .Values.hyperdx.ports.app }}
```

If you also need the OTEL collector exposed through the ALB, add a second entry:

```yaml
additionalManifests:
  # ... app Ingress above ...
  - apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: '{{ include "clickstack.fullname" . }}-alb-otel'
      annotations:
        alb.ingress.kubernetes.io/scheme: internal
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/group.name: clickstack-otel
        alb.ingress.kubernetes.io/healthcheck-path: /
        alb.ingress.kubernetes.io/healthcheck-port: "13133"
    spec:
      ingressClassName: alb
      rules:
        - host: otel.internal.example.com
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: '{{ include "clickstack.otel.fullname" . }}'
                    port:
                      number: 4318
```

For a complete, ready-to-use ALB example, see [`examples/alb-ingress/`](../examples/alb-ingress/).

### TargetGroupBinding

For ALB scenarios that require explicit TargetGroupBinding resources (e.g. pre-provisioned target groups):

```yaml
additionalManifests:
  - apiVersion: elbv2.k8s.aws/v1beta1
    kind: TargetGroupBinding
    metadata:
      name: '{{ include "clickstack.fullname" . }}-tgb'
    spec:
      serviceRef:
        name: '{{ include "clickstack.fullname" . }}-app'
        port: {{ .Values.hyperdx.ports.app }}
      targetGroupARN: "arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/my-tg/abc123"
      targetType: ip
```

## Tips

### Quoting template expressions

YAML requires `{{` to be inside a quoted string. Always use single quotes around values that contain template expressions:

```yaml
# Correct
name: '{{ include "clickstack.fullname" . }}'

# Incorrect -- YAML parse error
name: {{ include "clickstack.fullname" . }}
```

### Helm hooks

Each `additionalManifests` entry is rendered as a separate YAML document. You can add Helm hook annotations to control install/upgrade ordering:

```yaml
additionalManifests:
  - apiVersion: batch/v1
    kind: Job
    metadata:
      name: post-install-job
      annotations:
        helm.sh/hook: post-install
        helm.sh/hook-delete-policy: hook-succeeded
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: migrate
              image: my-migration-image:latest
              command: ["./migrate.sh"]
```

### CRD ordering

If your additional manifests include custom resource instances (e.g. `PodMonitor`), the CRDs must already exist in the cluster. Install CRDs before the chart release, either via the operator chart (`clickstack-operators`) or a separate step. Helm installs CRDs from `crds/` before templates, but `additionalManifests` entries are normal templates and cannot define CRDs.

### Combining multiple resources

You can define as many entries as needed. They are rendered in list order:

```yaml
additionalManifests:
  - apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: '{{ include "clickstack.fullname" . }}'
  - apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: '{{ include "clickstack.fullname" . }}-netpol'
    spec:
      podSelector: {}
  - apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: '{{ include "clickstack.fullname" . }}-hpa'
    spec:
      scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: '{{ include "clickstack.fullname" . }}-app'
      minReplicas: 2
      maxReplicas: 10
```
