#!/usr/bin/env python3
"""Repository-wide validation used for the final check and in CI.

- Parses every YAML file in the repo (syntax).
- Runs a lightweight brace/paren balance check on every .tf file as a proxy for
  `terraform fmt`/`validate` when Terraform is not installed locally.
"""
import glob
import sys

import yaml

# Helm templates/ are Go templates, not plain YAML — they are validated by
# `helm lint`/`helm template`, so only the chart's values files are parsed here.
YAML_GLOBS = [
    "helm/sample-web-app/values*.yaml",
    "helm/sample-web-app/Chart.yaml",
    "k8s/**/*.yaml",
    "argocd/**/*.yaml",
    ".github/**/*.yml",
]
TF_GLOB = "terraform/**/*.tf"


def check_yaml():
    ok = True
    count = 0
    for pattern in YAML_GLOBS:
        for path in glob.glob(pattern, recursive=True):
            count += 1
            try:
                list(yaml.safe_load_all(open(path, encoding="utf-8")))
            except yaml.YAMLError as exc:
                ok = False
                print(f"YAML FAIL {path}: {exc}")
    print(f"YAML: {count} files parsed, {'PASS' if ok else 'FAIL'}")
    return ok


def check_tf():
    ok = True
    count = 0
    for path in glob.glob(TF_GLOB, recursive=True):
        count += 1
        text = open(path, encoding="utf-8").read()
        # Strip string/heredoc noise is overkill here; our .tf uses balanced
        # delimiters, so a raw balance check catches accidental edits.
        for opener, closer in (("{", "}"), ("[", "]"), ("(", ")")):
            if text.count(opener) != text.count(closer):
                ok = False
                print(
                    f"TF FAIL {path}: unbalanced '{opener}{closer}' "
                    f"({text.count(opener)} vs {text.count(closer)})"
                )
    print(f"TF: {count} files checked, {'PASS' if ok else 'FAIL'}")
    return ok


if __name__ == "__main__":
    results = [check_yaml(), check_tf()]
    sys.exit(0 if all(results) else 1)
