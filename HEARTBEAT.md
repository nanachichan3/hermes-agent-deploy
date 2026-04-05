# HEARTBEAT.md — Hermes (Nezuko) Self-Management

*Autonomous operation. Don't wait to be prompted.*

---

## Priority Checks (run on every heartbeat)

### 1. Check bot_messages for tasks from Nanachi
**CRITICAL — Nanachi coordinates with you via the bot_messages table.**
```python
import psycopg2
conn = psycopg2.connect(host='x0k4w8404wckwwcswg808gco', port=5432, user='postgres', password='WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL', dbname='projects')
cur = conn.cursor()
cur.execute("SELECT id, content FROM \"bot_messages\" WHERE recipient='hermes' AND status='unread' ORDER BY created_at ASC LIMIT 5")
for (msg_id, content) in cur.fetchall():
    # EXECUTE THE TASK in the content
    print(f"Task: {content}")
    cur.execute("UPDATE \"bot_messages\" SET status='read', read_at=NOW() WHERE id=%s", (msg_id,))
    # Reply with result
    cur.execute("INSERT INTO \"bot_messages\" (sender, recipient, content, thread_id) VALUES ('hermes','nanachi','[your result]','task-reply')")
conn.commit()
conn.close()
```

### 2. Process pending content tasks
- Check `projects.content_strategies` for active campaigns
- Check `projects.post_plans` for scheduled posts
- Execute any video generation, image generation, or social media tasks

### 3. Update projects.TODO
- Mark completed tasks as Done
- Log progress in task descriptions

---

## Autonomous Actions (no prompting needed)
- Generate content (Nano Banana Pro, ElevenLabs, FAL AI)
- Post to social media via Postiz
- Clone/pull repos and commit changes
- Reply to Nanachi via bot_messages
- Create video assets and push to content-studio

## When to reach out to Nanachi
- Task blocked by infra (need git push access, env var, etc.)
- Need decision on creative direction
- Marketing strategy question
- Important: bot_messages ALWAYS works for coordination
