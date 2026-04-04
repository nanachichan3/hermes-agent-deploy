#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Write .env at runtime (overrides any baked values from image layers)
# Use := instead of :- to catch empty-string vars (Coolify may pass HERMES_MODEL="")
{
    echo "# Hermes Agent - generated at container start"
    echo "HERMES_MODEL=${HERMES_MODEL:=minimax/minimax-m2.7}"
    echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER:=openrouter}"
    echo "HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT:-18790}"
    echo "HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
    echo "GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-false}"
    echo "DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS:-588858125126336544}"
    echo "DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION:-false}"
    echo "DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}"
} > "$HERMES_HOME/.env"

# Also write config.yaml at runtime to ensure hermes always has the model set
{
    echo 'model: "minimax/minimax-m2.7"'
    echo 'fallback_providers: []'
} > "$HERMES_HOME/config.yaml"

# Set HERMES_MODEL explicitly in the current environment so hermes picks it up
# (hermes reads HERMES_MODEL env var directly, not just from .env)
# Use := to handle empty-string vars (Coolify may pass HERMES_MODEL="")
export HERMES_MODEL="${HERMES_MODEL:=minimax/minimax-m2.7}"
export HERMES_INFERENCE_PROVIDER="${HERMES_INFERENCE_PROVIDER:=openrouter}"
export HERMES_GATEWAY_PORT="${HERMES_GATEWAY_PORT:-18790}"
export HERMES_BACKGROUND_NOTIFICATIONS="${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
export GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:-false}"
export DISCORD_ALLOWED_USERS="${DISCORD_ALLOWED_USERS:-588858125126336544}"
export DISCORD_REQUIRE_MENTION="${DISCORD_REQUIRE_MENTION:-false}"
export DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
export DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"

# Run as hermes user so HERMES_HOME=/home/hermes resolves correctly
exec su hermes -s /bin/bash -c "
    export HERMES_MODEL=\"${HERMES_MODEL}\"
    export HERMES_INFERENCE_PROVIDER=\"${HERMES_INFERENCE_PROVIDER}\"
    export HERMES_GATEWAY_PORT=\"${HERMES_GATEWAY_PORT}\"
    export HERMES_BACKGROUND_NOTIFICATIONS=\"${HERMES_BACKGROUND_NOTIFICATIONS}\"
    export GATEWAY_ALLOW_ALL_USERS=\"${GATEWAY_ALLOW_ALL_USERS}\"
    export DISCORD_ALLOWED_USERS=\"${DISCORD_ALLOWED_USERS}\"
    export DISCORD_REQUIRE_MENTION=\"${DISCORD_REQUIRE_MENTION}\"
    export DISCORD_FREE_RESPONSE_CHANNELS=\"${DISCORD_FREE_RESPONSE_CHANNELS}\"
    export OPENROUTER_API_KEY=\"${OPENROUTER_API_KEY}\"
    export DISCORD_BOT_TOKEN=\"${DISCORD_BOT_TOKEN}\"
    /opt/venv/bin/hermes gateway run
"
