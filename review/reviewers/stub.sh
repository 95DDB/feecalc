#!/usr/bin/env bash
# Placeholder reviewer. Prints an empty findings file marked as a stub, so the
# review gate can tell "nothing found" apart from "nobody looked".
# Replace with a real reviewer per review/README.md.
set -euo pipefail
name="${1:?usage: stub.sh <reviewer-name>}"
jq -n --arg r "$name" '{reviewer: $r, vendor: "none", status: "stub", findings: []}'
