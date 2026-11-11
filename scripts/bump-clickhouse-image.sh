#!/usr/bin/env bash
# Moves the ClickHouse server and keeper images to the newest patch on their current release line
# (e.g. 26.8, an LTS). Moving to a new line stays manual. Prints the new tag, or nothing if up to date.
set -euo pipefail

VALUES="charts/clickstack/values.yaml"
HUB="https://hub.docker.com/v2/namespaces/clickhouse/repositories"
CURL=(curl -sS --connect-timeout 10 --max-time 30 --retry 2)

current=$(yq '.clickhouse.cluster.spec.containerTemplate.image.tag' "$VALUES")
line=$(cut -d. -f1-2 <<<"$current")
# ClickHouse LTS releases are the .3 and .8 of each year.
[[ $line =~ ^[0-9]+\.(3|8)$ ]] || { echo "::error::$current is not on an LTS line" >&2; exit 1; }

# Only full four-part versions: Docker Hub also has moving tags like 26.8.36-alpine.
latest=$("${CURL[@]}" -f "$HUB/clickhouse-server/tags?page_size=100&ordering=last_updated&name=$line." \
  | jq -r '.results[].name' \
  | grep -E "^${line//./\\.}\.[0-9]+\.[0-9]+-alpine$" \
  | sort -V | tail -n1) || { echo "::error::no $line alpine tags found on Docker Hub" >&2; exit 1; }

if [[ $(printf '%s\n' "$current" "$latest" | sort -V | tail -n1) == "$current" ]]; then
  exit 0
fi

# Keeper is published separately; on a 404 wait for the next run rather than split the versions.
code=$("${CURL[@]}" -o /dev/null -w '%{http_code}' "$HUB/clickhouse-keeper/tags/$latest") || code=failed
case $code in
  200) ;;
  404) echo "::warning::clickhouse-keeper has no $latest tag yet" >&2; exit 0 ;;
  *) echo "::error::Docker Hub keeper lookup for $latest returned $code" >&2; exit 1 ;;
esac

sed -i.bak -E "/clickhouse\/clickhouse-(server|keeper)$/{n;s/tag: \"[^\"]*\"/tag: \"$latest\"/;}" "$VALUES"
rm "$VALUES.bak"
for image in cluster keeper; do
  [[ $(yq ".clickhouse.$image.spec.containerTemplate.image.tag" "$VALUES") == "$latest" ]] \
    || { echo "::error::failed to set the $image tag in $VALUES" >&2; exit 1; }
done
echo "$latest"
