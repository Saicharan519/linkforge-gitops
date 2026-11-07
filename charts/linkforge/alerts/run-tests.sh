#!/usr/bin/env bash
# Validate and unit-test the alert rules with promtool, from a Prometheus image pinned by DIGEST (a tag could be
# re-pointed). The image is docker.io/prom/prometheus v3.16.0 (the version the chart deploys); promtool is in it.
#   charts/linkforge/alerts/run-tests.sh
set -euo pipefail
IMAGE="prom/prometheus@sha256:e04987641b57704f408e31f6373ba4138ecf27cb4a165d24aabb6c38fddd0f06"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run() { docker run --rm --entrypoint promtool -v "$DIR:/alerts:ro" -w /alerts/tests "$IMAGE" "$@"; }
echo "== promtool check rules"
run check rules /alerts/linkforge-rules.yaml
echo "== promtool test rules"
run test rules linkforge-rules.test.yaml
