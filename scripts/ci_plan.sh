#!/usr/bin/env bash
set -euo pipefail
umask 077

private_dir="${CI_PRIVATE_DIR:-.private}"
mkdir -p "$private_dir"
chmod 700 "$private_dir"
plan_file="$private_dir/ci.plan"
json_file="$private_dir/ci-plan.json"
log_file="$private_dir/ci-plan.log"
summary_file="$private_dir/ci-plan-summary.txt"

# A failed or empty run must not leave an earlier plan available to apply.
for artifact in "$plan_file" "$json_file" "$summary_file"; do
  if [ -e "$artifact" ] || [ -L "$artifact" ]; then
    unlink "$artifact"
  fi
done

set +e
tofu plan -detailed-exitcode -input=false -no-color -out="$plan_file" > "$log_file" 2>&1
status=$?
set -e

case "$status" in
  0)
    printf 'Plan: no changes. Private log: %s\n' "$log_file"
    exit 0
    ;;
  2)
    if ! tofu show -json "$plan_file" > "$json_file" 2>> "$log_file"; then
      printf 'Could not summarize plan. Private log: %s\n' "$log_file" >&2
      exit 1
    fi
    if ! python3 - "$json_file" > "$summary_file" 2>> "$log_file" <<'PY'
import collections
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    plan = json.load(file)

counts = collections.Counter()
for resource in plan.get("resource_changes", []):
    actions = resource.get("change", {}).get("actions", [])
    if actions == ["no-op"]:
        continue
    action = "replace" if "create" in actions and "delete" in actions else "+".join(actions)
    counts[(action, resource.get("type", "unknown"))] += 1

output_count = sum(
    output.get("change", {}).get("actions", []) != ["no-op"]
    for output in plan.get("output_changes", {}).values()
)

print("Plan: changes detected (action, resource type, count):")
for (action, resource_type), count in sorted(counts.items()):
    print(f"  {action} {resource_type}: {count}")
print(f"  outputs changed: {output_count}")
PY
    then
      printf 'Could not summarize plan. Private log: %s\n' "$log_file" >&2
      exit 1
    fi
    cat "$summary_file"
    printf 'Private plan and log: %s\n' "$private_dir"
    exit 2
    ;;
  *)
    printf 'Plan failed. Private log: %s\n' "$log_file" >&2
    exit 1
    ;;
esac
