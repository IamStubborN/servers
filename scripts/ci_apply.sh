#!/usr/bin/env bash
set -euo pipefail
umask 077

private_dir="${CI_PRIVATE_DIR:-.private}"
plan_file="$private_dir/ci.plan"
log_file="$private_dir/ci-apply.log"

if [ ! -f "$plan_file" ]; then
  printf 'Saved plan is missing: %s\n' "$plan_file" >&2
  exit 1
fi

if tofu apply -input=false -no-color "$plan_file" > "$log_file" 2>&1; then
  printf 'Apply completed. Private log: %s\n' "$log_file"
else
  printf 'Apply failed. Private log: %s\n' "$log_file" >&2
  exit 1
fi
