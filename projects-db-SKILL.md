# SKILL.md — ProjectsDatabase Framework

*Nanachi's canonical working environment. All agents operate through this database.*

---

## Database Access

**Connection:** `postgres://postgres:[PASS]@x0k4w8404wckwwcswg808gco:5432/projects`

**Python access pattern:**
```python
import psycopg2
HOST = 'x0k4w8404wckwwcswg808gco'
PORT = 5432
USER = 'postgres'
PASS = 'WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL'
conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASS, dbname='projects')
```

**MCP access:** `ProjectsDatabase__execute_sql` (via MetaMCP gateway at `https://metamcp.rachkovan.com`)

---

## Core Schema

### `Projects` — active ventures
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | project name |
| Status | text | Idea / MVP / Active / In Progress / Done / Archived |
| MRR | numeric | monthly recurring revenue |
| Active_Users | bigint | |
| Reach | bigint | |
| Internal_Use | boolean | true = internal tooling |
| Slogan | text | |
| URL | text | link to repo/app |
| Comment | text | notes |
| created_at / updated_at | timestamptz | |
| created_by | varchar | agent name |

### `Agents` — registered agents
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | agent name (e.g. "Nanachi", "Hermes") |
| Status | text | Active / Idle / Error |
| created_at / updated_at | timestamptz | |
| created_by | varchar | "system" |

**Current agents:** Nanachi (id=1)

### `TODO` — tasks linked to projects and agents
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | task description |
| Priority | text | Low / Medium / High / Critical |
| Status | text | To Do / In Progress / Done / Blocked |
| Description | text | full details, links |
| Projects_id | integer | FK → Projects |
| Agents_id | integer | FK → Agents |
| created_at / updated_at | timestamptz | |
| created_by / updated_by | varchar | |

### `Documents` — research, drafts, artifacts
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | doc title |
| Content | text | full content |
| Projects_id | integer | FK → Projects |
| created_by | varchar | agent name |
| created_at / updated_at | timestamptz | |

### `Channels` — distribution channels per project
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | channel name |
| Platform | text | discord / telegram / notion / github / internal |
| Projects_id | integer | FK → Projects |

### `Directories` — external resources/links per project
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | directory name |
| Link | text | URL |
| Reach | bigint | |
| Projects_id | integer | FK → Projects |

### `content_strategies` — A/B tested content approaches
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | strategy name |
| hypothesis | text | what we're testing |
| project_id | integer | FK → Projects |
| status | text | active / paused / completed |
| experiment_log | text | JSON log of results |
| created_by | varchar | |

### `post_plans` — scheduled social media posts
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| project_id | integer | FK → Projects |
| title / topic / content_type | text | |
| caption / script / hashtags | text | |
| status | text | draft / scheduled / posted / failed |
| scheduled_for | timestamptz | |
| platform | text | twitter / instagram / linkedin / youtube |

### `video_generations` — therapist content pipeline
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| post_plan_id | integer | |
| story_title / story_slug | text | |
| story_json | text | full episode manifest |
| stage | text | generating / compositing / voiced / done |
| character_prompts | text | JSON |
| generated_at / updated_at | timestamptz | |

### `research_documents` — structured research
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| project_id | integer | FK → Projects |
| title / content | text | |
| created_by | varchar | |

### `Partners` — people/organizations per project
| Column | Type | Notes |
|--------|------|-------|
| id | serial | PK |
| title | text | name |
| Platform / Notes / Reach | text | |
| Projects_id | integer | FK → Projects |

---

## Standard Operations

### Register a new agent
```sql
INSERT INTO "Agents" (title, Status, created_by)
VALUES ('Hermes', 'Active', 'system')
RETURNING id;
```

### Create a task
```sql
INSERT INTO "TODO" (title, Priority, Status, Description, Projects_id, Agents_id, created_by)
VALUES ('Deploy DeerFlow to Coolify', 'High', 'To Do',
        'Use coolify-cli. Repo: nanachichan3/deer-flow. Env: MINIMAX_API_KEY needed.',
        11, 1, 'Nanachi')
RETURNING id;
```

### Update task status
```sql
UPDATE "TODO" SET Status = 'Done', updated_at = NOW(), updated_by = 'Nanachi' WHERE id = 42;
```

### Assign task to agent
```sql
UPDATE "TODO" SET Agents_id = 2 WHERE id = 42;
```

### Check all active tasks for an agent
```sql
SELECT t.id, t.title, t.Priority, t.Status, p.title as project, t.Description
FROM "TODO" t
JOIN "Projects" p ON t.Projects_id = p.id
WHERE t.Agents_id = 1 AND t.Status NOT IN ('Done', 'Blocked')
ORDER BY 
  CASE t.Priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END,
  t.updated_at DESC;
```

### Log a document / research output
```sql
INSERT INTO "Documents" (title, Content, Projects_id, created_by)
VALUES ('Week in AI Education — 2026-04-05', '[full article]', 10, 'Nanachi');
```

### Check project health
```sql
SELECT 
  p.title,
  p.Status,
  COUNT(DISTINCT t.id) FILTER (WHERE t.Status NOT IN ('Done','Blocked')) as active_tasks,
  COUNT(DISTINCT d.id) as total_docs,
  MAX(t.updated_at) as last_task_update
FROM "Projects" p
LEFT JOIN "TODO" t ON t.Projects_id = p.id
LEFT JOIN "Documents" d ON d.Projects_id = p.id
WHERE p.Status NOT IN ('Archived','Idea')
GROUP BY p.id
ORDER BY active_tasks DESC;
```

### Full heartbeat check (replaces crypto/status spam)
```sql
-- Agent status check
SELECT title, Status FROM "Agents";

-- Overdue tasks
SELECT t.title, t.Status, p.title as project, t.Priority
FROM "TODO" t JOIN "Projects" p ON t.Projects_id = p.id
WHERE t.Status = 'In Progress' 
  AND t.updated_at < NOW() - INTERVAL '2 days'
ORDER BY t.Priority DESC;

-- Projects needing attention
SELECT title, Status FROM "Projects"
WHERE Status NOT IN ('Done','Archived','Idea')
  AND updated_at < NOW() - INTERVAL '3 days';
```

---

## Inter-Agent Communication

**Table:** `postgres.bot_messages` (not in projects DB — separate DB)

**Schema:**
```sql
CREATE TABLE bot_messages (
    id          SERIAL PRIMARY KEY,
    sender      VARCHAR(50)  NOT NULL,
    recipient   VARCHAR(50)  NOT NULL,
    content     TEXT         NOT NULL,
    thread_id   VARCHAR(100),
    status      VARCHAR(20)  NOT NULL DEFAULT 'unread',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    read_at     TIMESTAMPTZ
);
```

**Python tools** (`bot_coord.py` in hermes-agent-deploy):
```bash
# Read unread messages
python3 bot_coord.py read nanachi

# Send a message
python3 bot_coord.py post nanachi hermes "Check projects DB: any blocked tasks?" --thread <id>

# Mark as read
python3 bot_coord.py mark 42
```

**Real-time (LISTEN/NOTIFY):** Instead of polling, agents can use:
```python
conn = psycopg2.connect(...)
conn.execute("LISTEN new_message")
while True:
    if select.select([conn],[],[], 30) != ([],[],[]):
        conn.poll()
        for notify in conn.notifies():
            print("Got:", notify.payload)
```

---

## Heartbeat Protocol (Updated)

**OLD (delete):** Check BTC prices, generic status, email summary
**NEW:** Query the DB first. Only speak if something needs action.

```
Heartbeat check order:
1. agents WHERE Status != 'Active'  → alert if agent down
2. TODO WHERE Status = 'In Progress' AND updated_at < NOW() - 2 days → alert if stale
3. Projects WHERE Status = 'In Progress' AND updated_at < NOW() - 3 days → log
4. Cron job last run times → alert if overdue
If nothing → HEARTBEAT_OK (say nothing)

Delivery: Discord only. Telegram = urgent/breakage only.
```

---

## Hermes MCP Access (via MetaMCP)

MetaMCP gateway: `https://metamcp.rachkovan.com`

Hermes connects via HTTP MCP. To use `ProjectsDatabase`:
```
POST https://metamcp.rachkovan.com/rpc
Authorization: Bearer [Hermes API key]
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "execute_sql",
    "arguments": {"sql": "SELECT * FROM \"Projects\" ORDER BY id"}
  },
  "id": 1
}
```

---

## Framework Evolution Log

| Date | Change |
|------|--------|
| 2026-04-05 | Created. Defined core schema + heartbeat protocol. |
