#!/usr/bin/env bash
set -euo pipefail

{
  instance_id="$(tofu state show -no-color module.oracle.oci_core_instance.this 2>/dev/null | awk -F'= ' '/^ *id +=/ { gsub(/"/, "", $2); print $2; exit }' || true)"

  if [ -z "$instance_id" ]; then
    tofu apply -auto-approve -input=false -no-color
    exit 0
  fi

  set +e
  python scripts/oci_instance_status.py --instance-id "$instance_id" --replace-exit-code
  status=$?
  set -e

  if [ "$status" -eq 2 ]; then
    tofu apply -replace=module.oracle.oci_core_instance.this -auto-approve -input=false -no-color
  elif [ "$status" -eq 0 ]; then
    tofu apply -auto-approve -input=false -no-color
  else
    exit "$status"
  fi
} 2>&1 | sed -E \
  -e 's/ocid1\.[[:alnum:]._-]+/[redacted-ocid]/g' \
  -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[redacted-ip]/g'
