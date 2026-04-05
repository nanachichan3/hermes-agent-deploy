---
name: projects-db-framework
description: Employee handbook for Yev's company operations. Use whenever working on projects, assigning tasks, managing agents, storing documents, or coordinating with other AI agents (Hermes, DeerFlow). This is the canonical source of truth for how the company works — who does what, what projects exist, what tasks are pending, and how agents communicate. Triggers on: "how do we work", "what projects do we have", "assign this task", "check project status", "update the roadmap", "coordinate with Hermes", "add a document", "who is working on what".
---

# Projects DB Framework — Employee Handbook

*This is how we run things. Read this before asking Yev questions about the company.*

---

## Company Overview

We are a small, agent-driven company building in public. We use AI agents as the primary workforce. Yev (the founder) sets direction; agents execute.

**Core principles:**
- Everything lives in the **projects database** — not in Slack, not in Notion, not in someone's inbox
- Every project has an owner (agent or human)
- Every task has an assignee and a status
- Agent-to-agent communication happens through the `bot_messages` table

---

## The Projects Database (`projects`)

**Connection:** `pg-nanachi:5432/projects` — via postgres MCP or bot_coord.py

### Core Tables

| Table | What it's for |
|-------|---------------|
| `Projects` | Every project we work on. Name, status, MRR, reach, URL |
| `TODO` | Tasks attached to projects. Title, status, priority, who owns it |
| `Agents` | All AI agents in the fleet. Name, status, workspace, deployment |
| `Documents` | Company documents, research, PRDs |
| `Channels` | Where we communicate (Discord, Telegram, etc.) |
| `Partners` | People and companies we work with |
| `bot_messages` | Inter-agent messages (Nanachi ↔ Hermes ↔ DeerFlow) |

### Project Statuses
- **Idea** — Not started, no active work
- **MVP** — In active development
- **Launched** — Live and generating value
- **Closed** — Archived, no longer active

### Agent Statuses
- **Active** — Running and working
- **Waits for input** — Blocked, needs direction
- **In-development** — Being built/deployed

---

## Our Current Projects (Sprint 4 — April 5-11)

1. **Self-Degree Framework** (MVP) — Book/course on self-directed education
2. **Hermes SMM Agent** (MVP) — Social media agent running on Coolify
3. **DeerFlow Builder Agent** (In-dev) — Coding agent on Coolify
4. **Projects DB Framework** (MVP) — This framework
5. **SOCOS CRM** (MVP) — CRM for relationship/network management
6. **DnDate** (Launched) — Dating app through D&D roleplay
7. **Content Studio** (MVP) — Video pipeline (Therapist series, etc.)
8. **Agentic Infrastructure** (—) — Core infra for agent fleet
9. **Yev's Personal Brand** (Launched) — Blog, social media
10. **Unvibe** (MVP) — Productivity/focus app
11. **Viewpulse** (Launched) — Analytics/metrics tool
12. **Certifiecat** (Idea) — Credentialing platform
13. **AI Fractional CTO** (Idea) — Consulting brand

*Full list: query `SELECT * FROM "Projects" ORDER BY updated_at DESC`*

---

## Task Management

### How to Read the TODO Queue
```sql
SELECT * FROM "TODO" 
WHERE status != 'Done' 
ORDER BY "Projects_id", "Priority" DESC
```

### How to Assign a Task
1. Find the project ID from `Projects`
2. Find the agent ID from `Agents` (or leave null for Yev)
3. Insert into `TODO` with title, priority, status='To Do'

### Priority Levels
- **High** — Do first, blockers get escalated
- **Medium** — Normal queue
- **Low** — When there's bandwidth

### Task Status Flow
`To Do` → `In Progress` → `Done` (or `Blocked` if stuck)

### Yev's Items
When Yev has action items, assign them to Yev and set status `To Do`. Yev checks the DB — don't email or DM unless urgent.

---

## Inter-Agent Communication

### How to Send a Message to Hermes
```sql
INSERT INTO "bot_messages" (sender, recipient, content, status, created_at)
VALUES ('nanachi', 'hermes', 'Your message here', 'unread', NOW())
```

### Hermes Polling Endpoint
Hermes polls `projects.bot_messages` every 30 seconds. Messages with `recipient='hermes'` and `status='unread'` are picked up.

### To Get Hermes to Do Something
1. Write a clear task into `bot_messages` with recipient `hermes`
2. Include: what to do, what tools/access it has, how to report back
3. Hermes writes results back to `bot_messages` (recipient=`nanachi`)

### Hermes Capabilities
- Python scripts via bot_coord.py
- Coolify API access
- FAL AI for media generation
- ElevenLabs for voice
- GitHub (commit, PR)

### When Hermes Can't Reach You
If Hermes has urgent questions and Discord/Telegram are down, it writes to `bot_messages` and waits.

---

## Heartbeat Protocol (Nanachi)

Every heartbeat check (every ~15 min):
1. Query `SELECT * FROM "TODO" WHERE status != 'Done' ORDER BY "Priority" DESC LIMIT 10`
2. Check for overdue tasks → flag to Yev
3. Check agent statuses → confirm Hermes is active
4. Check `bot_messages` for unread messages from Hermes
5. **Do NOT** report crypto prices, generic statuses, or things Yev didn't ask for
6. **Only** message Yev if there's a real blocker, urgent email, or calendar event <2h

### Announcements → Discord
All heartbeat updates, task completions, and status reports go to **Discord** (Yev's #general). Telegram is for urgent-only alerts.

---

## Other Databases

| DB | Contents | When to Use |
|----|---------|-------------|
| `monica` | CRM: contacts, relationships, goals, journal | When looking up people Yev knows |
| `character` | Roleplay character scenarios | For DnDate or therapy character work |
| `dndate` | DnDate app: players, characters, matches | DnDate development |
| `personal` | Yev's top lists: watch, play, read | Personal context, recommendations |
| `socos` | SOCOS CRM: contacts, interactions | SOCOS platform development |
| `selfdegree` | Self-Degree resources, platforms | Self-Degree book research |
| `postgres` | `bot_messages` only | Inter-agent comms coordination |

---

## Document Storage

Store company documents in `Documents` table with:
- `title` — descriptive name
- `Content` — the actual content
- `project_id` — which project it belongs to
- `agents_id` — who created it

Do NOT store documents in Google Drive or Notion — they get lost. The DB is the single source of truth.

---

## Adding New Projects or Agents

1. **New project:** Insert into `Projects` with title, status, agent_id
2. **New agent:** Insert into `Agents` with title, status, workspace, deployment
3. **New task:** Insert into `TODO` with title, project_id, assigned agent

Document the change in memory/YYYY-MM-DD.md

---

## Key Principles

1. **DB is truth.** If it's not in the DB, it doesn't exist as a company asset
2. **Tasks have owners.** If no one owns it, it's not getting done
3. **Communication is async.** Don't interrupt Yev unless it's critical
4. **Agents work in parallel.** Hermes can run tasks simultaneously with me
5. **Ship to openclaw-deploy.** Any infra changes (packages, compose, env) must land in the deploy repo

---

*Last updated: 2026-04-05 — Sprint 4*
