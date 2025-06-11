# helm-charts

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
