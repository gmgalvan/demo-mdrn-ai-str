# Observability, Slack Alerts, and LLM Bot

This guide adds a lightweight observability stack for the Kubernetes demo:

- Prometheus for metrics.
- Loki for logs.
- Promtail for shipping Kubernetes pod logs to Loki.
- Grafana for dashboards, log exploration, and alerting.
- Slack for notifications.
- An optional LLM bot that summarizes alerts and suggests likely causes.

## 1. Expose application metrics

The API exposes Prometheus metrics at:

```text
/metrics
```

Useful metric names:

```text
payment_api_info
process_resident_memory_bytes
python_gc_objects_collected_total
```

After deploying the app, verify metrics from the control plane:

```bash
curl http://<PAYMENT_API_CLUSTER_IP>/metrics
```

## 2. Deploy the observability stack

Deploy the demo app first, then apply the observability manifests:

```bash
kubectl apply -f k8s/observability/namespace.yaml
kubectl apply -f k8s/observability/prometheus.yaml
kubectl apply -f k8s/observability/loki.yaml
kubectl apply -f k8s/observability/promtail.yaml
kubectl apply -f k8s/observability/grafana.yaml
```

Verify:

```bash
kubectl get pods,svc -n observability
```

Expected services:

```text
grafana      NodePort   ...   3000:30300/TCP
prometheus   NodePort   ...   9090:30090/TCP
loki         ClusterIP  ...   3100/TCP
```

## 3. Access Grafana

Grafana runs on NodePort:

```text
30300
```

If the KodeKloud playground exposes ports through the UI, open port `30300`.

Default credentials:

```text
username: admin
password: admin
```

Anonymous viewer access is also enabled for the demo.

Grafana is already provisioned with two data sources:

```text
Prometheus
Loki
```

## 4. Query metrics in Grafana

Go to Grafana -> Explore -> Prometheus.

Try:

```promql
payment_api_info
```

Target health:

```promql
up{job="payment-api"}
```

Container memory for the application pods, if your cluster exposes cAdvisor
metrics to Prometheus:

```promql
container_memory_working_set_bytes{namespace="demo", pod=~"payment-api.*"}
```

## 5. Query logs in Grafana

Go to Grafana -> Explore -> Loki.

Show logs for the app namespace:

```logql
{namespace="demo"}
```

Show only the healthy app:

```logql
{namespace="demo", app="payment-api"}
```

Show the broken deployment logs:

```logql
{namespace="demo", app="payment-api-v2"}
```

For OOMKilled cases, the most useful evidence usually comes from Kubernetes
events and pod status, not application logs, because the process can be killed
before it flushes logs.

## 6. Create useful Grafana alerts

Create alerts in Grafana using Prometheus queries.

Application target unavailable:

```promql
up{job="payment-api"} == 0
```

Application metadata missing:

```promql
absent(payment_api_info)
```

High memory usage, if cAdvisor metrics are available:

```promql
container_memory_working_set_bytes{namespace="demo", pod=~"payment-api.*"} > 200 * 1024 * 1024
```

For pod restarts and OOMKilled alerts, add kube-state-metrics in a more complete
environment. In this lightweight demo, use `kubectl describe pod` and events for
the live troubleshooting part.

## 7. Send Grafana alerts to Slack

In Slack:

1. Create a channel, for example `#payment-api-alerts`.
2. Create an incoming webhook for that channel.
3. Copy the webhook URL.

In Grafana:

1. Go to Alerting -> Contact points.
2. Create a contact point.
3. Choose Slack.
4. Paste the Slack webhook URL.
5. Save and test.

Then create a notification policy that routes payment-api alerts to that Slack
contact point.

Do not commit Slack webhook URLs to the repository.

## 8. LLM bot architecture

The LLM bot should not replace Grafana alerts. It should enrich them.

Recommended flow:

```text
Kubernetes app
  -> Prometheus metrics
  -> Loki logs
  -> Grafana alert
  -> Slack channel
  -> LLM bot receives alert
  -> Bot queries Prometheus/Loki/Kubernetes
  -> Bot posts a concise diagnosis back to Slack
```

The bot needs:

```text
SLACK_BOT_TOKEN
SLACK_SIGNING_SECRET
SLACK_ALERT_CHANNEL_ID
PROMETHEUS_URL
LOKI_URL
LLM_API_KEY
```

Optional if the bot can inspect Kubernetes directly:

```text
KUBERNETES_SERVICE_HOST
KUBERNETES_SERVICE_PORT
```

## 9. What the LLM bot should read

For each alert, collect:

```text
Alert name
Namespace
Deployment or pod name
Current pod status
Recent restart count
Recent Kubernetes events
Recent Loki logs
Recent Prometheus metrics
Recent rollout history
```

For this demo, the bot should detect:

```text
CrashLoopBackOff
OOMKilled
Exit Code 137
memory limit: 16Mi
```

Expected Slack summary:

```text
payment-api-v2 is unhealthy.
The pod is in CrashLoopBackOff. The previous container was OOMKilled with exit
code 137. The deployment limits memory to 16Mi, which is too low for the
Python/FastAPI process. Recommended fix: raise memory request to 128Mi and
limit to 256Mi, then verify rollout status.
```

## 10. Minimal bot behavior

The bot should:

1. Receive a Slack event or slash command.
2. Parse the alert labels.
3. Query Prometheus for recent request failures and target health.
4. Query Loki for recent logs for the namespace/app.
5. Query Kubernetes for pod status and events if it has cluster access.
6. Ask the LLM for a short incident summary with probable cause and next action.
7. Post the result to the same Slack thread.

Keep the LLM prompt strict:

```text
You are an SRE assistant. Summarize the incident using only the provided
metrics, logs, events, and pod status. If evidence is missing, say so. Provide:
status, likely cause, evidence, next action, and verification command.
```

## 11. Clean up

```bash
kubectl delete namespace observability
```
