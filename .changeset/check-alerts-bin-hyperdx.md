---
"helm-charts": patch
---

fix(clickstack): start the check-alerts CronJob through `bin/hyperdx` on HyperDX images 2.22.0 and newer, so the task loads the image's own self-telemetry preload. Images built after the switch to the ClickStack Node SDK need this. Older image tags keep their previous command.
