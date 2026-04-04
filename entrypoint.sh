#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Fix permissions on mounted volume (may have wrong ownership)
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME"/{sessions,memories,skills,cron,backups}

# Override .env with runtime secrets (API keys may change)
{
    echo "# Hermes Agent - runtime overrides"
    echo "HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}"
    echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}"
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}"
} > "$HERMES_HOME/.env.override"

# Merge: use .env as base, .env.override as override
# (hermes loads .env, and .env.override vars take precedence via export)
export HERMES_MODEL DISCORD_BOT_TOKEN OPENROUTER_API_KEY

echo "✅ Hermes starting with HERMES_MODEL=$HERMES_MODEL"
exec hermes gateway
