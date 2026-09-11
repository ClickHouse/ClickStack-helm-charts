---
"helm-charts": minor
---

Allow resources to be specified for the wait-for-mongodb init container via `hyperdx.deployment.waitForMongodb.resources` (empty by default). Required in clusters that enforce namespace resource quotas, where containers without requests/limits are rejected. Also documents how to set MongoDB container resources through the MongoDBCommunity `statefulSet` spec override. Ports ClickHouse/ClickStack-helm-charts#187 to the current chart layout.
