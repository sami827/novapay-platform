# NovaPay Payment Gateway

## Overview & Purpose

NovaPay Payment Gateway is the transaction processing core of the NovaPay FinTech platform, responsible for authorising and recording payment events across card and wallet payment methods. It exists to provide a reliable, observable payment execution layer — exposing latency and error-rate signals that determine whether payment SLOs are being met.

## Service SLOs & Health Contract

### Health Contract
- Endpoint: `GET /health`
- Returns: `{"status": "healthy"}`
- Used by: Kubernetes liveness and readiness probes to determine pod health and traffic eligibility

### Service Level Objectives
| SLO | Target | Window |
|-----|--------|--------|
| Payment success rate | 99% of requests succeed | 30-day rolling |
| Payment latency | 99% of requests complete within 500ms | 30-day rolling |

### Current Status vs SLO
- Simulated success rate: 90% — **violates error rate SLO deliberately**
- Simulated latency: 10–500ms random — **at SLO boundary**

### SLO Violation Response
- Below success rate threshold: Grafana dashboard threshold turns red.
  ⚠️ Gap: No AlertManager configured. Violations are visible but not acted on.
  Production answer: AlertManager routes SLO breach to PagerDuty/Slack.
- Above latency threshold: Grafana dashboard threshold turns red.
  ⚠️ Gap: No AlertManager configured. Violations are visible but not acted on.
  Production answer: AlertManager routes p99 breach to on-call engineer.

## Architecture & Components

The Flask application is packaged as a Docker image and deployed 
in a Kubernetes cluster. When the app receives a POST request, 
the Kubernetes Service manages routing to the Flask pod. The 
ServiceMonitor tells Prometheus to scrape the /metrics endpoint 
exposed by the application every 15 seconds. Grafana uses 
Prometheus as its datasource and visualises payment latency, 
error rate, and transaction volume for engineers in real time.


| Component | Production Role | If It Disappears |
|---|---|---|
| Flask (Python) | Accepts and processes payment requests, exposes /health and /metrics endpoints | Payment processing stops entirely |
| Docker | Packages the Flask app and dependencies into a portable, reproducible image | Deployment consistency breaks — environment parity lost |
| Kubernetes | Orchestrates containers, keeps service alive, manages replica count and self-healing | All failure recovery becomes manual. No self-healing |
| Kubernetes Service | Exposes Flask app via stable ClusterIP and DNS name inside the cluster | Pod restarts break network routing. Prometheus and clients lose connection |
| ServiceMonitor | Tells Prometheus which services to scrape and at what interval | Prometheus scrapes nothing. Observability layer goes blind |
| Prometheus | Scrapes /metrics every 15s to measure business SLOs | No observability layer. SLO measurement stops |
| Grafana | Visualises scraped metrics from Prometheus | No visualisation. Response loop incomplete |


## Runbook

### Prerequisites
- Docker installed and running
- kind installed
- kubectl installed

### 1. Start the Lab
```bash
cd ~/novapay
./scripts/start-lab.sh
```

### 2. Deploy Payment Gateway
```bash
kubectl apply -f ~/novapay/k8s/
```

### 3. Expose Services
```bash
kubectl port-forward svc/novapay-payment-gateway 8080:80 -n default &
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &
```

### 4. Verify
```bash
curl http://localhost:8080/health
# Expected: {"service":"payment-gateway","status":"healthy"}
```

### 5. Access
- NovaPay API → http://localhost:8080
- Grafana → http://localhost:3000
- Prometheus → http://localhost:9090

### Known Issue
Payment gateway deploys to `default` namespace, not `novapay`.
Namespace mismatch — fix in deployment.yaml before next session.

## Reliability Gaps & Known Failure Modes

| Gap | Current State | Production Answer |
|---|---|---|
| No AlertManager routing | Violations visible in Grafana but nothing acts on them. Response loop incomplete. | Configure AlertManager to route SLO breaches to PagerDuty/Slack |
| Prometheus local storage | Pod restart loses scrape history. No metric persistence. | Thanos or Cortex for long-term storage |
| Grafana state not externalised | Pod restart wipes dashboard configuration | Persistent volume or Grafana provisioning config |
| No Horizontal Pod Autoscaler | Fixed 2 replicas. No automatic scaling under load. | HPA configured against request rate or CPU threshold |

### Known Configuration Issue
Payment gateway deploys to `default` namespace.
Intended namespace: `novapay`.
Fix: update `k8s/deployment.yaml` namespace field before next session.