# Monitoring and Observability Setup

## Metrics
Application metrics (video-processor):
- Request latency (p50/p95/p99) for API endpoints
- Error rate (5xx, exception count)
- Throughput: fragments/sec consumed, chunks/sec produced
- Kafka consumer lag per partition, rebalance count
- S3 upload success rate, retry count, upload latency

Infrastructure metrics (EKS):
- Node CPU/mem/disk, filesystem usage
- Pod CPU/mem, restarts, OOMKilled count
- HPA desired vs current replicas

Edge metrics:
- Edge uptime, CPU/mem/disk, GPU utilization
- VPN up/down state, upload bandwidth usage vs cap
- Local buffer usage (/var/video-buffer)

## SLOs (Service Level Objectives)
Platform SLOs:
- Availability:
  - Staging: 99.0% (monthly)
  - Production: 99.9% (monthly)
- Data freshness:
  - 99% within 5 minutes
- Processing reliability:
  - ≥ 99.5% of fragments processed without error (daily)
- Edge device:
  - ≥ 99.0% edge online (weekly)

## Alerting
Paging (immediate):
- Chunk upload failure rate > 2% for 10+ minutes
- Production deployment unavailable replicas > 0 for 5+ minutes
- Edge VPN down (site offline) for > 5 minutes

Ticket (non-urgent):
- Memory usage high (> 85%) sustained 30+ minutes
- Frequent pod restarts (e.g., > 3 restarts per pod per hour)
- HPA constantly at max replicas (capacity issue)

## Escalation

- L1 (auto):
  - Restart failed pod (K8s) or restart `video-ingest` systemd service (edge)
  - If rollback condition met, trigger rollback automation
- L2 (on-call engineer):
  - Investigate dashboards/logs, mitigate (scale, rollback, disable bad deploy)
- L3 (specialist / senior):
  - Kafka/MSK, networking/VPN, GPU/runtime, data pipeline owners
- Customer involvement:
  - If site outage > 30 minutes or data loss risk detected, notify customer contact

## Dashboards

1) Platform overview
- Availability, error rate, throughput, freshness (end-to-end)

2) Kafka/MSK
- Consumer lag, rebalances, produce/consume rate, broker health

3) S3 uploads
- Upload latency, retries, failures, bytes/sec, backlog

4) EKS workloads
- Pod CPU/mem, restarts/OOMKills, HPA scaling behavior, rollout status

5) Edge fleet
- Site uptime, VPN health, bandwidth usage, disk buffer utilization, camera connectivity