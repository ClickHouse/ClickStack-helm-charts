---
"helm-charts": patch
---

Clear all 7 dependency advisories in the release tooling. No chart changes.

`js-yaml` 3.14.1 → 3.15.2: a second copy pulled in transitively via
`@changesets/cli` → `read` → `parse`, carrying 3 highs and 2 moderates
(quadratic CPU in merge-key/`!!omap` handling, prototype pollution in `<<`).
The direct `js-yaml@^5.4.1` dependency was already fine; this is the older copy
the range already allowed to move.

`tmp` 0.0.33 → 0.2.7 via a `resolutions` override, clearing a high path
traversal (`<0.2.6`) and a low symlink issue. `external-editor` declares
`tmp@^0.0.33`, and a caret on a `0.0.x` version is semver-equivalent to
`=0.0.33`, so this cannot be re-resolved without the override. It calls only
`tmp.tmpNameSync()`, which 0.2.x still exports.

Both are reachable only through the release/changeset tooling, never at chart
render time.
