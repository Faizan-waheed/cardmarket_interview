#!/usr/bin/env bash
# Tear down the local cluster.
set -euo pipefail
CLUSTER_NAME="${CLUSTER_NAME:-interview}"
k3d cluster delete "${CLUSTER_NAME}"
