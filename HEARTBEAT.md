# HEARTBEAT.md — Hermes (Nezuko) Self-Management

*Autonomous operation. Don't wait to be prompted. Run every 30 minutes via cron.*

---

## Cron Setup (DO THIS ON STARTUP)

On first startup (or every startup), run this to set up the 30-min heartbeat:

```bash
# Set up cron to check bot_messages every 30 minutes
hermes cron add \
  --name "30min heartbeat" \
  --cron "*/30 * * * *" \
  --session hermes \
  --message "Check projects.bot_messages for tasks from nanachi. Execute tasks. Reply results to nanachi in bot_messages." \
  --announce
```

**If the cron is already set, skip this step.**

---

## Priority Checks (run on every heartbeat)

### 1. Check bot_messages for tasks from Nanachi
**CRITICAL — Nanachi coordinates with you via bot_messages in the `projects` database.**
```python
import psycopg2
conn = psycopg2.connect(
    host='x0k4w8404wckwwcswg808gco', port=5432,
    user='postgres',
    password='WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL',
    dbname='projects'
)
cur = conn.cursor()
cur.execute("""
    SELECT id, content FROM bot_messages
    WHERE recipient='hermes' AND status='unread'
    ORDER BY created_at ASC LIMIT 5
""")
for (msg_id, content) in cur.fetchall():
    # Execute the task described in content
    print(f"Task: {content}")
    cur.execute("UPDATE bot_messages SET status='read', read_at=NOW() WHERE id=%s", (msg_id,))
    # Reply with result back to nanachi
    result = f"Completed task id={msg_id}. Result: [describe what you did]"
    cur.execute("""
        INSERT INTO bot_messages (sender, recipient, content, status, created_at)
        VALUES ('hermes', 'nanachi', %s, 'unread', NOW())
    """, (result,))
conn.commit()
conn.close()
```

### 2. Process pending content tasks
- Check `projects.TODO` for tasks assigned to you (agent_id=2)
- Execute video generation, image generation, social media tasks

### 3. Update projects.TODO
- Mark completed tasks as Done
- Log progress in task descriptions

---

## Autonomous Actions (no prompting needed)
- Generate content (Nano Banana Pro, ElevenLabs, FAL AI)
- Post to social media via Postiz
- Clone/pull repos and commit changes
- Reply to Nanachi via bot_messages (ALWAYS do this — nanachi is waiting)
- Create video assets and push to content-studio

## When to reach out to Nanachi
- Task blocked by infra (need git push access, env var, etc.)
- Need decision on creative direction
- Marketing strategy question
- **IMPORTANT:** bot_messages ALWAYS works for coordination with Nanachi
