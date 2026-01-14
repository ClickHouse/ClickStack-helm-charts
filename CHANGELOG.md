# helm-charts

## 1.1.0

### Minor Changes

- 8fcee9a: Supports passing additional arguments to the check-alerts task. This allows setting the concurrency and sourceTimeoutMs through helm.

## 1.0.1

### Patch Changes

- 427edc5: chore: pull otel collector from the clickstack repo
- 0336c7a: chore: update appVersion to 2.8.0

## 1.0.0

### Major Changes

- edd8cc9: MIGRATION: Rename + Release chart `clickstack` (v1.0.0)

## 0.8.4

### Patch Changes

- 444109c: Further fixes to the cronjob to use the correct path and version.

## 0.8.3

### Patch Changes

- 3e18303: Fixes the alert cron job template so newer version image tags will use the updated command to start the task.

## 0.8.2

### Patch Changes

- e97c3d4: chore: update appVersion to 2.7.1

## 0.8.1

### Patch Changes

- 521b5a1: refactor: Parameterize hyperdx-deployment initContainer image and pullPolicy
- db5d20f: chore: update appVersion to 2.7.0

## 0.8.0

### Minor Changes

- 6bafe5c: feat: implement safe clickhouse upgrade process + resource limits support
- 6bafe5c: chore: bump clickhouse to v25.7

### Patch Changes

- ec2d5b2: fix: pin busybox image digest and add pull policy for init container

## 0.7.3

### Patch Changes

- 38e5d05: chore: update appVersion to 2.4.0
- 910ae39: chore: update appVersion to 2.5.0
- 9b374cb: chore: update appVersion to 2.6.0

## 0.7.2

### Patch Changes

- d13a098: feat: support custom otelcol config
- 3a36cf3: chore: update appVersion to 2.2.1

## 0.7.1

### Patch Changes

- 268c6e0: fix: Better backwards compatibility for app url for existing deployments

## 0.7.0

### Minor Changes

- 10737b0: fix: Allow for frontend url to be explicitly configured

### Patch Changes

- 33e0405: feat: Add secret support for default connections and sources

## 0.6.9

### Patch Changes

- 0f05519: chore: update appVersion to 2.1.2
- 2a8dac4: chore: Update appVersion to 2.1.1
- 76c6da5: feat: add livenessProbe and readinessProbe for services
- a06f212: feat: allows customizing additional ingresses service names to route to the correct otel collector service (with README update)
- 862b81f: feat: Add support for image pull secrets in deployments
- a06f212: feat: allows specifying ingress path and pathType for different ingress controllers
- 4a5194f: feat: option to keep all services PVCs when uninstalling helm

## 0.6.8

### Patch Changes

- 9db1d33: fix: rename CRON_IN_APP_DISABLED to RUN_SCHEDULED_TASKS_EXTERNALLY

## 0.6.7

### Patch Changes

- c2ffc45: chore: Update appVersion to 2.0.6
- c0d70d5: fix: update the new entrypoint since v2.0.2 (alert cronjob)

## 0.6.6

### Patch Changes

- b6ab8ff: feat: support set replica and resources for otel-collector
- f9c8a4c: feat: improve availability of HyperDX pods

## 0.6.5

### Patch Changes

- 40f2e89: feat: support servicetype and annotations for clickhouse svc

## 0.6.4

### Patch Changes

- d8ca4db: chore: Remove NEXT_PUBLIC_URL from configmap as it is not needed
- 46a37c6: feat: support nodeSelector and toleration
- b5881bd: fix: Update FRONTEND_URL to be dynamic w/ingress
- b82c57d: fix: Allow for configurable service type + annotations

## 0.6.3

### Patch Changes

- 39d37c5: fix if condition typo
- 3d75672: fix: Fix pathType for ingress

## 0.6.2

### Patch Changes

- d0650ed: Allows setting custom ingressClassName and annotations for the HyperDX application ingress.

## 0.6.1

### Patch Changes

- c117d72: fix: Allow for custom otel collector environment variables

## 0.6.0

### Minor Changes

- 7b964f1: Allow defining additional ingresses so resources outside of the HyperDX application can accept traffic outside of the cluster.
- 1541c5f: feat: refactor image value + bump default tag to 2.0.0

### Patch Changes

- cec5983: enable using remote mongodb

## 0.5.2

### Patch Changes

- 9493843: fix: relocate mongodb volume persistence field + handle the case when CH pvc is disabled
- 4e246da: feat: add 'clickhouseUser' and 'clickhousePassword' otel settings
- 8608668: chore: Remove snapshot tests and replace with assertions
