# HyperDX V2 Helm Charts

Welcome to the official HyperDX Helm charts repository. This guide provides instructions on how to install, configure, and manage your HyperDX V2 deployment using Helm.

## Prerequisites

- [Helm](https://helm.sh/) v3+
- Kubernetes cluster (v1.20+ recommended)
- `kubectl` configured to interact with your cluster

## Adding the HyperDX Helm Repository

First, add the HyperDX Helm repository:

```sh
helm repo add hyperdx https://hyperdxio.github.io/helm-charts
helm repo update
```

## Installing HyperDX

To install the HyperDX chart with default values:

```sh
helm install my-hyperdx hyperdx/hdx-oss-v2
```

You can customize settings by editing `values.yaml` or using `--set` flags.

```sh
helm install my-hyperdx hyperdx/hdx-oss-v2 -f values.yaml
```

or

```sh
helm install my-hyperdx hyperdx/hdx-oss-v2 --set key=value
```

To retrieve the default values:

```sh
helm show values hyperdx/hdx-oss-v2 > values.yaml
```

### Example Configuration

```yaml
replicaCount: 2
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - host: hyperdx.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
```

## Using Secrets

For handling sensitive data such as API keys or database credentials, use Kubernetes secrets. The HyperDX Helm charts provide default secret files that you can modify and apply to your cluster.

### Using Pre-Configured Secrets

The Helm chart includes a default secret template located at [`charts/hdx-oss-v2/templates/secrets.yaml`](https://github.com/hyperdxio/helm-charts/blob/main/charts/hdx-oss-v2/templates/secrets.yaml). This file provides a base structure for managing secrets.


If you need to manually apply a secret, modify and apply the provided `secrets.yaml` template:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hyperdx-secret
  annotations:
    "helm.sh/resource-policy": keep
type: Opaque
data:
  API_KEY: <base64-encoded-api-key>
```

Apply the secret to your cluster:

```sh
kubectl apply -f secrets.yaml
```

### Creating a Custom Secret

If you prefer, you can create a custom Kubernetes secret manually:

```sh
kubectl create secret generic hyperdx-secret \
  --from-literal=API_KEY=my-secret-api-key
```

### Referencing a Secret in `values.yaml`

```yaml
hyperdx:
  apiKey:
    valueFrom:
      secretKeyRef:
        name: hyperdx-secret
        key: API_KEY
```

## Task Configuration

By default, there is one task in the chart setup as a cronjob, responsible for checking whether alerts should fire. Here are its configuration options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tasks.enabled` | Enable/Disable cron tasks in the cluster. By default, the HyperDX image will run cron tasks intra process. Change to true if you'd rather use a separate cron task in the cluster. | `false` |
| `tasks.checkAlerts.schedule` | Cron schedule for the check-alerts task | `*/1 * * * *` |
| `tasks.checkAlerts.resources` | Resource requests and limits for the check-alerts task | See `values.yaml` |

## Upgrading the Chart

To upgrade to a newer version:

```sh
helm upgrade my-hyperdx hyperdx/hdx-oss-v2 -f values.yaml
```

To check available chart versions:

```sh
helm search repo hyperdx
```

## Uninstalling HyperDX

To remove the deployment:

```sh
helm uninstall my-hyperdx
```

This will remove all resources associated with the release, but persistent data (if any) may remain.

## Troubleshooting

### Checking Logs

```sh
kubectl logs -l app.kubernetes.io/name=hdx-oss-v2
```

### Debugging a Failed Install

```sh
helm install my-hyperdx hyperdx/hdx-oss-v2 --debug --dry-run
```

### Verifying Deployment

```sh
kubectl get pods -l app.kubernetes.io/name=hdx-oss-v2
```

For more details, refer to the [Helm documentation](https://helm.sh/docs/) or open an issue in this repository.

---

## Contributing

We welcome contributions! Please open an issue or submit a pull request if you have improvements or feature requests.

## License

This project is licensed under the [MIT License](LICENSE).

