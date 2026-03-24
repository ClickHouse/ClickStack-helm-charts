# ClickStack with AWS ALB Ingress

This example shows how to deploy ClickStack using an [AWS Application Load Balancer](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) instead of the chart's built-in nginx Ingress.

## What's included

The `values.yaml` in this directory:

- Disables the built-in nginx Ingress (`hyperdx.ingress.enabled: false`)
- Creates a public-facing ALB Ingress for the HyperDX app with HTTPS, SSL redirect, health checks, and session stickiness
- Creates an internal ALB Ingress for the OTEL collector endpoint
- Adds a HorizontalPodAutoscaler for the HyperDX deployment

All of these are defined via `additionalManifests`, which renders arbitrary Kubernetes objects alongside the chart's own resources.

## Prerequisites

1. **AWS Load Balancer Controller** installed in the cluster. See the [installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/).
2. **ACM certificate** provisioned for your domain. Replace the `certificate-arn` annotation value with your ARN.
3. **Subnets** tagged for ALB auto-discovery, or specify them explicitly via the `alb.ingress.kubernetes.io/subnets` annotation.

## Usage

```bash
# Install operators first (if not already installed)
helm install clickstack-operators clickstack/clickstack-operators

# Install ClickStack with ALB values
helm install my-clickstack clickstack/clickstack \
  -f examples/alb-ingress/values.yaml
```

## Customization

Edit `values.yaml` to match your environment:

| Setting | Where to change | Description |
|---------|-----------------|-------------|
| Domain | `rules[].host` | Replace `clickstack.example.com` and `otel.internal.example.com` with your domains |
| Certificate | `certificate-arn` annotation | Replace with your ACM certificate ARN |
| ALB scheme | `scheme` annotation | `internet-facing` for public, `internal` for private |
| Subnets | Add `subnets` annotation | Explicit subnet IDs if auto-discovery is not configured |
| HPA thresholds | `minReplicas`, `maxReplicas`, `averageUtilization` | Tune autoscaling to your workload |

## Further reading

- [Additional Manifests Guide](../../docs/ADDITIONAL-MANIFESTS.md) for the full reference on `additionalManifests`
- [AWS Load Balancer Controller annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/) for all available ALB annotations
