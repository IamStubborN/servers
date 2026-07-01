#!/usr/bin/env bash
set -euo pipefail

instance_id="$(tofu output -raw oracle_instance_id)"
public_ip="$(tofu output -raw oracle_public_ip)"

python scripts/oci_instance_status.py --instance-id "$instance_id" --wait-running 300

PUBLIC_IP="$public_ip" python - <<'PY'
import os
import socket
import sys
import time

deadline = time.monotonic() + 180
last_error = None

while time.monotonic() < deadline:
    try:
        with socket.create_connection((os.environ["PUBLIC_IP"], 22), timeout=5):
            print("SSH port is reachable.")
            sys.exit(0)
    except OSError as exc:
        last_error = exc
        time.sleep(5)

print(f"SSH port did not become reachable: {last_error}", file=sys.stderr)
sys.exit(1)
PY
