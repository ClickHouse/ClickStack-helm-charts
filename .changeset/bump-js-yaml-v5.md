---
"helm-charts": patch
---

Bump `js-yaml` from ^4.2.0 to ^5.4.1 for the release tooling (`update-chart-versions.js`, `extract-release-notes.js`). No chart changes. Both scripts continue to work via the v5 CJS build; a new `version-script-smoke` CI job now exercises them at PR time so future dependency bumps cannot break releases silently. Also restores consistency between `package.json` and `yarn.lock`, which had drifted on main.
