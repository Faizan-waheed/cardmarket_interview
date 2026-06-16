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

echo "==> 5/6 Install ArgoCD"
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.extraArgs[0]="--insecure" \
  --wait --timeout 10m
kubectl apply -f "${REPO_ROOT}/k8s/argocd-app.yaml"

echo "==> 6/6 Apply ingresses"
kubectl apply -f "${REPO_ROOT}/k8s/monitoring-ingress.yaml"

echo ""
echo "Done. Add these to /etc/hosts:"
echo "  127.0.0.1 hello-app.local grafana.local jaeger.local argocd.local"
echo ""
echo "Then access:"
echo "  http://hello-app.local:8080"
echo "  http://grafana.local:8080     (admin / admin)"
echo "  http://jaeger.local:8080"
echo "  http://argocd.local:8080      (admin / get password below)"
echo ""
echo "  ArgoCD password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
