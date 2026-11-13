#!/usr/bin/env bash
#
# Scans mix.lock against the OSV advisory database.
#
# Exits non-zero when any locked Hex package has a known vulnerability, so CI
# fails on a newly published advisory instead of waiting for a dependency bump.
#
# Usage: scripts/osv_scan.sh [path/to/mix.lock]

set -euo pipefail

lockfile="${1:-mix.lock}"

if [[ ! -f "$lockfile" ]]; then
  echo "lockfile not found: $lockfile" >&2
  exit 1
fi

findings=0
checked=0

while read -r name version; do
  checked=$((checked + 1))

  response=$(curl -sf --retry 3 --retry-delay 2 \
    -X POST "https://api.osv.dev/v1/query" \
    -H "Content-Type: application/json" \
    -d "{\"package\":{\"name\":\"${name}\",\"ecosystem\":\"Hex\"},\"version\":\"${version}\"}")

  ids=$(printf '%s' "$response" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(",".join(vuln["id"] for vuln in data.get("vulns", [])))
' 2>/dev/null || true)

  if [[ -n "$ids" ]]; then
    findings=$((findings + 1))
    echo "VULNERABLE ${name} ${version} -> ${ids}"
  fi
done < <(grep -oE '"[a-z0-9_]+": \{:hex, :[a-z0-9_]+, "[^"]+"' "$lockfile" |
  sed -E 's/^"([a-z0-9_]+)".*"([0-9][^"]*)"$/\1 \2/')

echo "checked ${checked} packages against OSV, ${findings} with advisories"

if [[ "$findings" -gt 0 ]]; then
  exit 1
fi
