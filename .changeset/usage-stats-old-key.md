---
"helm-charts": patch
---

fix: fail rendering when the removed 1.x `hyperdx.usageStatsEnabled` key is set, instead of ignoring it and leaving usage stats on. Set `clickstack.config.USAGE_STATS_ENABLED: "false"` to opt out. The upgrade guide now lists the other 1.x `hyperdx.*` keys that moved.
