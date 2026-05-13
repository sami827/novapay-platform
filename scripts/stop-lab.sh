#!/bin/bash
echo "🛑 Stopping NovaPay Lab..."

# Kill port forwards
echo "→ Stopping port forwards..."
kill $(lsof -t -i:3000) 2>/dev/null && echo "  Grafana port-forward stopped" || echo "  No Grafana port-forward running"
kill $(lsof -t -i:8080) 2>/dev/null && echo "  NovaPay port-forward stopped" || echo "  No NovaPay port-forward running"

# Stop cluster gracefully
echo "→ Stopping kind cluster..."
docker stop novapay-local-control-plane
echo "  Cluster stopped"

# Stop Docker
echo "→ Stopping Docker..."
sudo service docker stop
echo "  Docker stopped"

echo ""
echo "✅ Lab stopped cleanly. Safe to close WSL."
