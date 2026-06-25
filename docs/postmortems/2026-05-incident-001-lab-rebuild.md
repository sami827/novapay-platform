# Postmortem: NovaPay Lab Environment Cold Rebuild

**Date:** May 11, 2026  
**Duration:** ~3 hours (19:00 – 22:00 ICT)  
**Severity:** Development environment - total loss of local cluster  
**Author:** Sami Al Sabbir  
**Status:** Resolved - permanent fixes applied

---

## Summary

The NovaPay development environment (kind cluster on WSL2) became unrecoverable after Docker was shut down while the cluster was still running. The resulting containerd filesystem corruption, combined with a previously undetected platform architecture mismatch (ARM vs AMD64 images), required a full cold rebuild of the lab - downloading all images from scratch, recreating the cluster, and redeploying all workloads. Total recovery time: approximately 3 hours.

## Impact

- **What was affected:** Entire local development cluster - kind, all NovaPay pods, Prometheus, Grafana, Alertmanager
- **Duration:** ~3 hours of development time lost
- **Data loss:** No persistent data lost (no stateful workloads). All source code intact in Git. Configuration and manifests intact.
- **Blast radius:** Development environment only. No production systems affected.

## Timeline (ICT, May 11 2026)

| Time | Event |
|------|-------|
| ~19:00 | Developer shuts down Docker Desktop. Kind cluster was still running inside Docker containers. |
| ~19:05 | Attempt to restart Docker and the cluster. `docker start novapay-local-control-plane` fails with **RWLayer is nil** error. Containerd filesystem layers are corrupted. |
| ~19:10 | Decision made to delete and recreate the kind cluster (`kind delete cluster`). This was premature - a Docker restart (`sudo service docker restart`) should have been attempted first and may have resolved the corruption without data loss. |
| ~19:15 | Fresh kind cluster created successfully. Pods enter **ImagePullBackOff** - the local containerd image cache was wiped with the old cluster. All images need to be reloaded. |
| ~19:20 | `docker pull` for base images begins. Multiple images needed: Flask app, Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter, configmap-reload. |
| ~19:45 | `kind load docker-image` fails with **content digest not found** for several images. Root cause identified: images were originally pulled without `--platform linux/amd64`. WSL2 runs on an AMD64 kernel but Docker's default pull includes multi-platform manifests that kind's containerd cannot import. |
| ~20:00 | All images re-pulled with explicit `--platform linux/amd64` flag. Loads into kind succeed. |
| ~20:30 | Application manifests reapplied. Flask pods running. Prometheus scraping resumed. |
| ~21:00 | Grafana dashboards and Alertmanager configuration restored from saved YAML files. |
| ~21:30 | Full verification complete - all pods healthy, metrics flowing, alerts configured. |
| ~22:00 | Recovery scripts written and tested. Local image backups saved to `~/novapay/backups/`. Lab fully operational. |

## Root Cause Analysis

**Primary cause:** Docker was shut down while the kind cluster was running. Kind runs Kubernetes inside Docker containers. When Docker exits without gracefully stopping those containers, the containerd filesystem layers (RWLayer) become corrupted. This is not recoverable by restarting Docker alone once corruption has occurred.

**Contributing factor 1 - No local image cache.** All container images existed only in the kind cluster's containerd cache. When the cluster was deleted, the images were lost. Re-downloading ~1.5GB of images from Docker Hub added significant recovery time and introduced rate-limiting risk.

**Contributing factor 2 - Platform architecture mismatch.** Images were originally pulled without `--platform linux/amd64`. On WSL2, Docker's default pull includes multi-platform manifests. Kind's containerd on WSL2 cannot import these manifests - it requires platform-specific images. This issue was latent from initial setup and only surfaced during the cold rebuild.

**Contributing factor 3 - Premature escalation.** Recovery jumped from "restart the container" directly to "delete and recreate the cluster" (Level 1 to Level 4 on the recovery ladder). A Docker service restart (Level 2) was not attempted and may have resolved the RWLayer corruption without losing the image cache.

## What Went Well

- All source code, manifests, and configuration files were in Git - nothing was lost permanently
- The incident exposed the platform mismatch bug that had been latent since initial setup
- Recovery was completed same-session - no overnight blockers
- The experience directly informed the creation of recovery automation

## Action Items

| Action | Status | Type |
|--------|--------|------|
| Create `stop-lab.sh` script that stops the kind cluster before Docker shutdown | ✅ Complete | Prevention |
| Create `recover-lab.sh` script that automates the full rebuild process | ✅ Complete | Mitigation |
| Save all images as `.tar` files to `~/novapay/backups/` after any successful setup | ✅ Complete | Mitigation |
| Always pull images with `--platform linux/amd64` on WSL2 | ✅ Complete | Prevention |
| Document the recovery ladder in the lab cheatsheet: restart component → restart Docker → recreate cluster → full rebuild | ✅ Complete | Process |
| Add systemd verification to the pre-flight check in `start-lab.sh` | ✅ Complete | Prevention |

## Recovery Ladder (established post-incident)

When the kind cluster fails, follow this order - escalate only if the previous step fails:

```
Level 1 - Restart the container (30 seconds)
  docker start novapay-local-control-plane

Level 2 - Restart Docker and retry (2 minutes)
  sudo service docker restart
  sleep 10
  docker start novapay-local-control-plane
  kubectl get nodes

Level 3 - Delete and recreate cluster with warm cache (5-10 minutes)
  kind delete cluster --name novapay-local
  kind create cluster --name novapay-local
  # Reload from local .tar backups

Level 4 - Full cold rebuild (last resort, 30+ minutes)
  # Re-pull all images with --platform linux/amd64
  # Recreate cluster, reload, redeploy all workloads
```

## Lessons Learned

1. **Your dev environment is infrastructure too.** If rebuilding it takes 3 hours and lives in your head, it is a single point of failure. Automate the recovery and document the failure mode.

2. **Minimum effective intervention.** Always try the least destructive fix first. Understand the blast radius of every action before you take it. A senior engineer asks WHY before they act; a junior engineer acts first and understands later.

3. **Latent bugs surface under stress.** The platform mismatch existed from Day 1 but only appeared during the cold rebuild. Production systems have similar latent issues - the only way to find them is to actually test recovery procedures.

4. **Shutdown order matters.** Dependent systems must be stopped in reverse dependency order. Kind depends on Docker. Stop kind first, then Docker. Same principle applies to any layered system - application before database, pods before nodes, cluster before container runtime.

---

*This postmortem follows the blameless format: no individual blame, focus on systems and processes, actionable improvements. Written as part of the NovaPay platform engineering project.*
