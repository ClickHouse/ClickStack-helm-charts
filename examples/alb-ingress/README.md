# ClickStack with AWS ALB Ingress

This example shows how to deploy ClickStack using an [AWS Application Load Balancer](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) with the chart's passthrough ingress pattern.

## What's included

The `values.yaml` in this directory:

- Configures the primary ingress with ALB annotations and spec (public-facing, HTTPS, health checks, session stickiness)
- Adds an internal ALB ingress for the OTEL collector endpoint via `additionalIngresses`
- Enables a HorizontalPodAutoscaler for the HyperDX deployment

The primary ingress uses the chart's passthrough pattern: `annotations` and `spec` are rendered verbatim, so any ALB-specific configuration is expressed directly in values.

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

# Or, from this directory:
# helm install my-clickstack clickstack/clickstack -f values.yaml
```

## Customization

| Setting | Where to change | Description |
|---------|-----------------|-------------|
| Domain | `spec.rules[].host` | Replace `clickstack.example.com` and `otel.internal.example.com` with your domains |
| Certificate | `certificate-arn` annotation | Replace with your ACM certificate ARN |
| ALB scheme | `scheme` annotation | `internet-facing` for public, `internal` for private |
| Subnets | Add `subnets` annotation | Explicit subnet IDs if auto-discovery is not configured |
| HPA thresholds | `autoscaling.spec` | Tune minReplicas, maxReplicas, and metric targets |

## Further reading

- [Additional Manifests Guide](../../docs/ADDITIONAL-MANIFESTS.md) for the `additionalManifests` power feature
- [AWS Load Balancer Controller annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/) for all available ALB annotations
