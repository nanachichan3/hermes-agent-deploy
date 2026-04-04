#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Write .env at runtime (overrides any baked values from image layers)
# Env vars from docker-compose are passed through and take precedence
{
    echo "# Hermes Agent - generated at container start"
    echo "HERMES_MODEL=${HERMES_MODEL:-minimax/minimax-m2.7}"
    echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}"
    echo "HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT:-18790}"
    echo "HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
    echo "GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-false}"
    echo "DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS:-588858125126336544}"
    echo "DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION:-false}"
    echo "DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}"
} > "$HERMES_HOME/.env"

exec hermes gateway run
