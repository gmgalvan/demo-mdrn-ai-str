# KodeKloud Deployment Guide

Use this guide after cloning the repository inside a KodeKloud Kubernetes
playground.

## 1. Clone the repository

```bash
git clone https://github.com/gmgalvan/demo-mdrn-ai-str.git
cd demo-mdrn-ai-str
```

## 2. Point Kubernetes manifests to Docker Hub

The original manifests use a local `kind` image named `payment-api:demo`.
In KodeKloud, the cluster needs to pull the image from Docker Hub.

```bash
sed -i 's|image: payment-api:demo|image: docker.io/docker7gm/demo-mdrn-ai-str:latest|g' k8s/deployment-healthy.yaml k8s/deployment-broken.yaml
sed -i 's|imagePullPolicy: Never|imagePullPolicy: Always|g' k8s/deployment-healthy.yaml k8s/deployment-broken.yaml
```

## 3. Deploy the healthy application

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/deployment-healthy.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/payment-api -n demo
kubectl get pods,svc -n demo
```

Expected result:

```text
deployment "payment-api" successfully rolled out
pod/payment-api-...   1/1   Running
service/payment-api   NodePort   ...   80:30080/TCP
```

## 4. Test the service from the control plane

Use the service ClusterIP shown by `kubectl get svc -n demo`:

```bash
curl http://<SERVICE_CLUSTER_IP>/health
curl http://<SERVICE_CLUSTER_IP>/payments
```

Or test through Kubernetes DNS:

```bash
kubectl run curl-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://payment-api.demo.svc.cluster.local/health
```

Expected health response:

```json
{"status":"ok"}
```

## 5. Access the app from a browser

The service is exposed as a `NodePort` on port `30080`.

In the KodeKloud playground UI, look for an option such as:

```text
View Port
Access Ports
Open Port
```

Open port:

```text
30080
```

Useful paths:

```text
/health
/payments
/docs
```

The `/docs` path opens the FastAPI Swagger UI.

## 6. Optional: Use port-forward

If browser port access is not available, use `kubectl port-forward`:

```bash
kubectl port-forward svc/payment-api 8080:80 -n demo --address 0.0.0.0
```

Then test from another terminal:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/payments
```

## 7. Start the troubleshooting demo

Deploy the intentionally broken workload:

```bash
kubectl apply -f k8s/deployment-broken.yaml
kubectl get pods -n demo
```

The new `payment-api-v2` pod should eventually fail because its memory limit is
too low for the Python/FastAPI process.

Useful diagnostic commands:

```bash
kubectl describe pod -n demo -l app=payment-api-v2
kubectl logs -n demo -l app=payment-api-v2 --previous
kubectl get events -n demo --sort-by=.lastTimestamp
```

## 8. Clean up

Delete the demo namespace:

```bash
kubectl delete namespace demo
```
