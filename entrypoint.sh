#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"
HERMES_DIR="$HERMES_HOME"

# Ensure hermes home is writable
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
mkdir -p "$HERMES_HOME/.hermes"/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME/.hermes"/{logs,sessions,memories,skills,cron,backups}

# Write .env — this OVERWRITES any existing .env
# Env vars set via docker-compose are already in the shell environment
# and take precedence (they override .env values)
{
    echo "# Hermes Agent - generated at container start"
    echo "HERMES_MODEL=${HERMES_MODEL:-openrouter:minimax/minimax-m2.7}"
    echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:-openrouter}"
    echo "HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT:-18790}"
    echo "HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
    echo "GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-false}"
    echo "DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS:-588858125126336544}"
    echo "DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION:-false}"
    echo "DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"
    # API keys
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}"
    echo "OPENAI_API_KEY=${OPENAI_API_KEY:-}"
    echo "MINIMAX_API_KEY=${MINIMAX_API_KEY:-}"
} > "$HERMES_HOME/.env"

# Write config.yaml (for reference, though .env/env vars are primary)
cat > "$HERMES_HOME/config.yaml" << 'CONFIG'
model: "openrouter:minimax/minimax-m2.7"
fallback_providers: []
discord:
  require_mention: false
  free_response_channels: "1484900474363842643"
CONFIG

echo "✅ Hermes config ready"
echo "--- $HERMES_HOME/.env ---"
cat "$HERMES_HOME/.env"

exec hermes gateway
