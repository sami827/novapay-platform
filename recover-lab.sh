#!/bin/bash
echo "🔧 NovaPay Lab — Full Recovery"
echo ""

# Start Docker
echo "→ Starting Docker..."
sudo service docker start
sleep 3

# Load all images from local backups
echo "→ Loading images from local backups..."
docker load -i ~/novapay/backups/kindest-node-v1.29.2.tar
docker load -i ~/novapay/backups/grafana-13.0.1.tar
docker load -i ~/novapay/backups/prometheus.tar
docker load -i ~/novapay/backups/alertmanager.tar
docker load -i ~/novapay/backups/k8s-sidecar.tar
docker load -i ~/novapay/backups/prometheus-config-reloader.tar
docker load -i ~/novapay/backups/novapay-payment-gateway.tar

# Delete corrupted cluster if exists
echo "→ Cleaning up old cluster..."
kind delete cluster --name novapay-local 2>/dev/null || true

# Recreate cluster
echo "→ Creating fresh cluster..."
kind create cluster --name novapay-local --config ~/kind-config.yaml

# Verify node
kubectl get nodes

# Load images into kind
echo "→ Loading images into kind..."
kind load docker-image --platform linux/amd64 grafana/grafana:13.0.1 --name novapay-local
kind load docker-image --platform linux/amd64 quay.io/kiwigrid/k8s-sidecar:2.7.1 --name novapay-local
kind load docker-image --platform linux/amd64 quay.io/prometheus/prometheus:v3.11.3-distroless --name novapay-local
kind load docker-image --platform linux/amd64 quay.io/prometheus/alertmanager:v0.32.1 --name novapay-local
kind load docker-image --platform linux/amd64 quay.io/prometheus-operator/prometheus-config-reloader:v0.90.1 --name novapay-local
kind load docker-image novapay-payment-gateway:v1 --name novapay-local

# Reinstall monitoring stack
echo "→ Installing monitoring stack..."
kubectl create namespace monitoring 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring

echo ""
echo "⏳ Wait ~2 minutes for monitoring stack to start"
echo "   Run: kubectl get pods -n monitoring"
echo ""
echo "✅ Recovery complete — no internet needed!"
