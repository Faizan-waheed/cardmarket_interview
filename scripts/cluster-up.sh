#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-interview}"
IMAGE="${IMAGE:-hello-app:local}"
APP_VERSION="${APP_VERSION:-1.0.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PATH="$HOME/.local/bin:$PATH"

echo "==> 1/6 Create k3d cluster '${CLUSTER_NAME}'"
if k3d cluster list | grep -q "^${CLUSTER_NAME}\b"; then
  echo "    already exists, skipping"
else
  k3d cluster create "${CLUSTER_NAME}" --agents 1 --port "8080:80@loadbalancer" --wait
fi

echo "==> 2/6 Build and import app image"
docker build --build-arg "APP_VERSION=${APP_VERSION}" -t "${IMAGE}" "${REPO_ROOT}/app"
k3d image import "${IMAGE}" -c "${CLUSTER_NAME}"

echo "==> 3/6 Install kube-prometheus-stack (Prometheus + Grafana)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout 10m

echo "==> 4/6 Install Jaeger"
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --set allInOne.enabled=true \
  --set collector.enabled=false \
  --set query.enabled=false \
  --set agent.enabled=false \
  --wait --timeout 5m

echo "==> 5/6 Deploy hello-app"
helm upgrade --install hello-app "${REPO_ROOT}/charts/hello-app" \
  --namespace app --create-namespace \
  --set image.repository="${IMAGE%:*}" \
  --set image.tag="${IMAGE##*:}" \
  --set image.pullPolicy=Never \
  --set serviceMonitor.enabled=true \
  --set jaeger.endpoint="http://jaeger-all-in-one.monitoring:14268/api/traces" \
  --wait --timeout 5m

echo "==> 6/6 Done."
echo ""
echo "  # App:"
echo "  kubectl -n app port-forward svc/hello-app 8081:80"
echo "  curl localhost:8081/"
echo ""
echo "  # Grafana (admin/admin):"
echo "  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
echo ""
echo "  # Jaeger UI:"
echo "  kubectl -n monitoring port-forward svc/jaeger-query 16686:16686"
