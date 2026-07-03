# KodeKloud: Accessing the Observability Stack UIs

Notes for reaching Grafana and Prometheus from a KodeKloud Kubernetes
playground once [k8s/observability/](../k8s/observability/) is deployed (see
[observability-slack-llm.md](observability-slack-llm.md)).

## 1. Try the NodePort first

Both services are exposed as `NodePort`, which already listens on every node
interface — no port-forward needed:

```text
Grafana:    30300
Prometheus: 30090
```

In the KodeKloud playground UI, use "View Port" (or "Access Ports" / "Open
Port") and enter the port number above.

## 2. If the NodePort view doesn't work, use port-forward with `--address 0.0.0.0`

`kubectl port-forward` binds to `127.0.0.1`/`::1` by default. KodeKloud's
port-viewer proxy connects from outside that loopback, so a plain
port-forward looks healthy in the terminal but the browser tab shows
`502 Bad Gateway`.

Run it bound to all interfaces, in the background so it doesn't block the
terminal:

```bash
kubectl port-forward svc/grafana 3000:3000 -n observability --address 0.0.0.0 &
kubectl port-forward svc/prometheus 9090:9090 -n observability --address 0.0.0.0 &
```

Then "View Port" → `3000` (Grafana) or `9090` (Prometheus).

Do not `Ctrl+C` the port-forward before opening the port in the browser —
that kills the listener and produces the same 502.

To stop them later:

```bash
kill %1 %2
# or
pkill -f "port-forward svc/grafana"
pkill -f "port-forward svc/prometheus"
```
