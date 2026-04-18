# workspace-sync — Distributed Consensus PR Workflow

*Shared workspace git sync + cross-harness PR review. Each harness reviews and approves other harnesses' changes before merge.*

## Overview

All 3 harnesses (Nanachi, Bezuko, Rick) share the same workspace git repos. Every 30 minutes, each harness:
1. Syncs latest from shared workspace repos
2. Creates a PR if it made changes (from its branch → main)
3. Reviews open PRs from other harnesses
4. Auto-approves if changes look valid (not destructive, not duplicate)
5. Merges any PR with ≥1 approval from a different harness

This means no single harness can unilaterally change the shared workspace — changes require cross-harness consensus.

## Prerequisites

Each harness needs:
- `GH_TOKEN` with write access to the shared workspace repos
- `HARNESS_NAME` env var: `nanachi`, `bezuko`, or `rick`
- Git identity set: `user.name` and `user.email`

## The Workflow Script

Located at `scripts/pr-workflow.sh`. Run it every 30 minutes via cron:

```bash
bash /data/workspace/skills/workspace-sync/scripts/pr-workflow.sh /data/workspace nanachi
```

## Shared Workspace Repos

Each harness syncs from these repos:
- **CEO workspace:** `yevgeniusr/openclaw-deploy` → `/data/workspace`
- **CMO workspace:** `nanachichan3/factory-cmo-deploy` → `/data/agents/cmo`
- **CTO workspace:** `nanachichan3/hermes-agent-deploy` → `/data/agents/cto`

## Safety Rules

1. **Never force push to main**
2. **Never delete workspace directories**
3. **Never merge without at least 1 cross-harness approval**
4. **Auto-reject if changes include: `rm -rf`, `.git/`, `secrets`, `*.env` with real keys**
5. **If local changes conflict with remote, create a conflict-resolution PR and notify**

## Monitoring

```bash
tail -n 20 /data/workspace/memory/pr-workflow.log
gh pr list --state open
```
