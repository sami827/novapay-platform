#!/bin/bash
echo "🚀 Starting NovaPay Lab..."

# Start Docker
echo "→ Starting Docker..."
sudo service docker start
sleep 3

# Check if cluster is running
if docker ps | grep -q "novapay-local-control-plane"; then
    echo "→ Cluster already running"
else
    echo "→ Starting kind cluster..."
    docker start novapay-local-control-plane
    sleep 30
fi

# Verify cluster is healthy
echo "→ Checking cluster health..."
kubectl get nodes

# Check monitoring stack
echo "→ Checking monitoring stack..."
kubectl get pods -n monitoring --no-headers | grep -v Running && echo "⚠️  Some pods not ready yet — wait 30s and check manually" || echo "✅ Monitoring stack healthy"

echo ""
echo "✅ Lab is ready!"
echo ""
echo "Run these to access services:"
echo "  kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &"
echo "  kubectl port-forward svc/payment-gateway 8080:80 &"
echo ""
echo "  Grafana  → http://localhost:3000"
echo "  NovaPay  → http://localhost:8080/health"
