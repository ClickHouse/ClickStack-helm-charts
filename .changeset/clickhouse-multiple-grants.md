---
"helm-charts": patch
---

fix: every grant on a ClickHouse user now applies. A `grants` list under `clickhouse.cluster.spec.settings.extraUsersConfig.users` rendered as repeated `<grants>` elements, and ClickHouse applied only the first one, so a user with several grants was missing permissions with no error. The chart now renders the list as one `grants` block with all its queries. Lists of `{query: ...}` maps, plain query strings and an existing `grants: {query: [...]}` block all work. Before upgrading, check each user's grants list: entries after the first take effect for the first time.
