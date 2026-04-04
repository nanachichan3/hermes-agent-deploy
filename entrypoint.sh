#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Write .env (runtime secrets override baked values)
{
    echo "# Hermes runtime config"
    echo "HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}"
    echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}"
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}"
    echo "HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT:-18790}"
    echo "HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
    echo "GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-false}"
} > "$HERMES_HOME/.env"

echo "✅ Written .env with HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}"

# Debug: show what hermes config actually sees
echo "=== hermes config show ==="
export HERMES_HOME
hermes config show

echo ""
echo "=== Starting gateway ==="
exec hermes gateway run -v
