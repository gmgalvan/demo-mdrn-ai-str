# Prompts for the live demos

Copy and paste as-is into Claude Code during the talk.

---

## Demo 1 — The agent implements an endpoint and opens a PR

> **Before the demo:** clean repo on `main`, tests green (`uv run pytest`),
> GitHub MCP server connected.

```
Implement a new GET /health/detailed endpoint in payment-api that returns:
- version: the app version (the one already defined in FastAPI)
- uptime_seconds: seconds since the process started
- database: status of a mock database connection (always "connected",
  with a simulated latency_ms)

Follow the project conventions (CLAUDE.md). Add the corresponding tests and
run the whole suite to confirm it passes green. Then use the project's PR
workflow: create a feature branch, commit and open a Pull Request.
Remember: only open the PR, never merge it.
```

**What to expect:** the agent reads `CLAUDE.md`, implements the endpoint in
`app/routers/health.py` with type hints and an English docstring, adds tests
in `tests/test_health.py`, runs `uv run pytest`, uses the `pr-workflow`
skill (and the `pr-reviewer` subagent to review the diff), and opens the PR
via GitHub MCP. It finishes by showing the PR URL.

---

## Demo 2 — The agent diagnoses a broken pod in Kubernetes

> **Before the demo:** run `./scripts/break-demo.sh` and verify that
> `payment-api-v2` is in CrashLoopBackOff. Kubernetes MCP server connected.

```
Something is wrong with payment-api-v2 in the demo namespace of the cluster:
the pod does not come up and keeps restarting. Diagnose the problem, find
the root cause and propose the fix. IMPORTANT: do not apply any change to
the cluster without my explicit approval.
```

**What to expect:** the agent uses the `k8s-diagnostics` skill (or the
`sre-diagnostics` subagent): describes the pod, sees `OOMKilled` in
Last State and the restart counter, correlates the events, inspects the
deployment and finds the 16Mi limit. It proposes raising the memory limit
(e.g. to the 128Mi/256Mi of the healthy deployment) showing the exact
change, and **stops to ask for approval**. You approve live, the agent
applies the fix and verifies the pod ends up `Running`.

---

## Backup phrases (in case the agent drifts)

- Demo 1, if it does not run the tests: `Run uv run pytest before opening the PR.`
- Demo 1, if it tries to commit to main: `Check the branch conventions in CLAUDE.md.`
- Demo 2, if it tries to apply without permission: `Stop: first show me the diagnosis and the proposed fix.`
- Demo 2, to close: `Approved, apply the fix and verify the pod becomes healthy.`
