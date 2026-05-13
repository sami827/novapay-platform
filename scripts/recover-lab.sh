#!/bin/bash
echo "🔧 NovaPay Lab — Full Recovery"
echo "Use this when cluster is corrupted or missing"
echo ""

# Start Docker
echo "→ Starting Docker..."
sudo service docker start
sleep 3

# Load kind image from local backup if needed
if ! docker images | grep -q "kindest/node"; then
    echo "→ Loading kind image from backup..."
    docker load -i ~/novapay/kindest-node-v1.29.2.tar
fi

# Delete corrupted cluster if exists
echo "→ Cleaning up old cluster..."
kind delete cluster --name novapay-local 2>/dev/null || true

# Recreate cluster
echo "→ Creating fresh cluster..."
kind create cluster --name novapay-local --config ~/kind-config.yaml

# Verify node
echo "→ Verifying cluster..."
kubectl get nodes

# Reinstall monitoring stack
echo "→ Installing monitoring stack..."
kubectl create namespace monitoring 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring

# Reload NovaPay image
echo "→ Loading NovaPay image..."
kind load docker-image novapay-payment-gateway:v1 --name novapay-local

echo ""
echo "⏳ Monitoring stack takes ~2 minutes to fully start"
echo "   Run: kubectl get pods -n monitoring"
echo "   Wait until all pods show Running"
echo ""
echo "✅ Recovery complete!"
