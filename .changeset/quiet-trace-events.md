---
"helm-charts": patch
---

feat: update the default HyperDX sources to match the current source schema (only applies to new installs; existing sources are not modified)

- Traces: set `spanEventsValueExpression: "Events"` and `spanLinksValueExpression: "Links"` so span events (including exceptions) and span links are shown
- Metrics: register the `summary` and `exponential histogram` metric tables
- Remove fields HyperDX ignores for each source kind (e.g. log-style fields on the Sessions source, stray `_id`/`id` keys in `metricTables`)
