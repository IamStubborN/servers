#!/usr/bin/env python3
import argparse
import os
import sys
import time

import oci
from oci.exceptions import ServiceError


REPLACE_STATES = {"TERMINATED", "TERMINATING"}


def build_config():
    return {
        "fingerprint": os.environ["TF_VAR_fingerprint"],
        "key_file": os.environ["TF_VAR_private_key_path"],
        "region": os.environ["TF_VAR_region"],
        "tenancy": os.environ["TF_VAR_tenancy_ocid"],
        "user": os.environ["TF_VAR_user_ocid"],
    }


def get_lifecycle_state(client, instance_id):
    try:
        return client.get_instance(instance_id).data.lifecycle_state
    except ServiceError as exc:
        if exc.status == 404:
            return "NOT_FOUND"
        raise


def wait_for_running(client, instance_id, timeout_seconds):
    deadline = time.monotonic() + timeout_seconds
    state = get_lifecycle_state(client, instance_id)

    while state != "RUNNING" and time.monotonic() < deadline:
        if state in REPLACE_STATES or state == "NOT_FOUND":
            break

        time.sleep(10)
        state = get_lifecycle_state(client, instance_id)

    return state


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instance-id", required=True)
    parser.add_argument("--replace-exit-code", action="store_true")
    parser.add_argument("--wait-running", type=int, default=0)
    args = parser.parse_args()

    config = build_config()
    oci.config.validate_config(config)
    client = oci.core.ComputeClient(config)

    if args.wait_running:
        state = wait_for_running(client, args.instance_id, args.wait_running)
    else:
        state = get_lifecycle_state(client, args.instance_id)

    print(f"Oracle instance lifecycle: {state}")

    if args.replace_exit_code and (state in REPLACE_STATES or state == "NOT_FOUND"):
        return 2

    if args.wait_running and state != "RUNNING":
        print(f"Oracle instance did not reach RUNNING: {state}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
