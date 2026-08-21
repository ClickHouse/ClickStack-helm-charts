---
"helm-charts": patch
---

ci: attach the matching CHANGELOG.md section to each GitHub release. The release workflow now extracts the released version's changelog section into `charts/clickstack/RELEASE_NOTES.md` and passes it to chart-releaser via `release-notes-file`, instead of publishing releases with only the chart description as the body.
