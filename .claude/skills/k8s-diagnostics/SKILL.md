---
name: k8s-diagnostics
description: Structured diagnosis of failing pods in Kubernetes (CrashLoopBackOff, OOMKilled, ImagePullBackOff, etc.). Use when the user reports a failing pod, constant restarts, or a service down in the cluster.
---

# Kubernetes pod diagnostics

Structured flow to diagnose a failing pod. Follow the steps in order and
report the findings of each step before proposing a fix.

## Golden rule

**Read-only during diagnosis.** Never run `kubectl apply`, `edit`, `patch`,
`delete`, `scale` or any write operation without explicit user approval.
First present the diagnosis and the proposed fix; the user decides.

## Steps

### 1. Overall pod status

```
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod> -n <namespace>
```

Look at: current state (`CrashLoopBackOff`, `Pending`, etc.), restart
count, and in `Last State` the reason for the last termination
(`OOMKilled`, `Error`, exit code).

### 2. Namespace events

```
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

Look for scheduling events, failing probes, memory kills and restart
back-off. Correlate timestamps with the pod restarts.

### 3. Container logs

```
kubectl logs <pod> -n <namespace> --previous
kubectl logs <pod> -n <namespace>
```

Use `--previous` when the container has already restarted: that is where
the crash log lives. If the process died from OOM there may be no error
trace in the log (the kernel kills the process without warning) — the
absence of an error is also a signal.

### 4. Resources: requests and limits

```
kubectl get deployment <deployment> -n <namespace> -o yaml
```

Review `resources.requests` and `resources.limits`. Compare the memory
limit with the expected process footprint. Typical signals:

- `OOMKilled` + very low memory limit → the limit is not even enough for
  the process to start.
- Failing probes + very low CPU limit → the process starts too slowly.

### 5. Diagnosis and proposed fix

Present to the user:

1. **Root cause**: what is happening and why (with the evidence from
   steps 1–4).
2. **Proposed fix**: concrete change to the manifest (show the diff or
   the resulting YAML).
3. **Exact command** that would be executed to apply it.

Then **stop and ask for explicit approval**. Only apply the change if the
user answers affirmatively. After applying, verify with
`kubectl get pods -n <namespace>` that the pod is `Running` and stable.
