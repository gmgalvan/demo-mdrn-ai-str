---
name: pr-workflow
description: Standard flow to create a branch, commit and Pull Request in this repo. Use whenever a code change is ready to become a PR.
---

# Pull Request workflow

Standard flow to take a code change to a PR. Never merge: the PR is
opened and a human decides.

## Steps

### 1. Verify before committing

- Run `uv run pytest` and confirm everything passes green.
- Review the full diff (`git diff`) before committing: no secrets, no dead
  code, no accidental files. If the `pr-reviewer` subagent exists, use it
  for this review.

### 2. Create the branch

```
git checkout -b feature/<short-description>
```

- Always branch off an up-to-date `main`.
- Kebab-case name, descriptive and short: `feature/health-detailed-endpoint`.

### 3. Commit

- Conventional commits in English: `feat: ...`, `fix: ...`, `test: ...`,
  `docs: ...`, `refactor: ...`.
- One commit per logical unit of change. Imperative message:
  `feat: add /health/detailed endpoint with uptime and db status`.

### 4. Push and PR

```
git push -u origin feature/<short-description>
```

Open the PR (via GitHub MCP or `gh pr create`) with this structure in the
description:

```markdown
## Summary

What the change does and why, in 2-3 lines.

## Changes

- Bullet list of modified files/areas and what changed in each one.

## How to test

1. Concrete steps to verify the change locally.
2. Include the test command: `uv run pytest`.
3. If applicable, an example curl/request against the endpoint.
```

### 5. Final rules

- **Never merge the PR.** Only open it and share the URL.
- Do not commit directly to `main`.
- If tests fail, do not open the PR: fix first.
