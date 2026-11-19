---
"helm-charts": minor
---

feat: rename the top-level `hyperdx` values key to `clickstack`. Values files that still use `hyperdx` keep working and get a deprecation warning in the install notes; where both keys set the same value, `hyperdx` wins.
