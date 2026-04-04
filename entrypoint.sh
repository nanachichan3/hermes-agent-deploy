#!/bin/bash
set -e

# Ensure hermes home is writable (volume mount may have wrong ownership)
chown -R hermes:hermes /home/hermes/.hermes 2>/dev/null || true

# Create required subdirectories if missing (volume might be empty)
mkdir -p /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}

echo "✅ Hermes home ready at /home/hermes/.hermes"
ls -la /home/hermes/.hermes/

exec hermes gateway
