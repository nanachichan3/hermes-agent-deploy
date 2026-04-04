#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Write .env to /etc/hermes.env (NOT in the mounted volume path, so it can't be overridden)
# This ensures runtime values are always correct regardless of volume state
mkdir -p /etc/hermes
cat > /etc/hermes/hermes.env << ENVFILE
HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
ENVFILE

# Also overwrite the volume .env to ensure it's correct
cat > "$HERMES_HOME/.env" << ENVFILE
HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
ENVFILE

echo "✅ Hermes env ready"
echo "HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}"
echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}"

exec hermes gateway
