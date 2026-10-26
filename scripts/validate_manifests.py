#!/usr/bin/env python3
"""Offline structural validation for Kubernetes/YAML manifests.

Checks that every YAML document parses and contains the required top-level
keys (apiVersion, kind, metadata.name). This is a lightweight gate that runs
without a live cluster; CI additionally runs kubeconform for schema checks.

Usage: python scripts/validate_manifests.py <glob> [<glob> ...]
"""
import glob
import sys

import yaml

REQUIRED = ("apiVersion", "kind", "metadata")


def validate(patterns):
    ok = True
    checked = 0
    for pattern in patterns:
        for path in glob.glob(pattern, recursive=True):
            try:
                docs = list(yaml.safe_load_all(open(path, encoding="utf-8")))
            except yaml.YAMLError as exc:
                ok = False
                print(f"FAIL {path}: YAML parse error: {exc}")
                continue
            for i, doc in enumerate(docs):
                if doc is None:
                    continue
                checked += 1
                missing = [k for k in REQUIRED if k not in doc]
                if missing:
                    ok = False
                    print(f"FAIL {path} doc#{i}: missing {missing}")
                    continue
                name = doc.get("metadata", {}).get("name")
                if not name:
                    ok = False
                    print(f"FAIL {path} doc#{i}: metadata.name is empty")
                    continue
                print(f"OK   {path} doc#{i}: {doc['kind']}/{name}")
    print(f"\n{checked} document(s) checked; result: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    patterns = sys.argv[1:] or ["k8s/**/*.yaml"]
    sys.exit(validate(patterns))
