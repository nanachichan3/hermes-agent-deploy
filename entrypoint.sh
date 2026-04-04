#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Apply defaults FIRST — before any env vars are used or exported
# := assigns default when unset OR empty (catches Coolify passing HERMES_MODEL="")
HERMES_MODEL="${HERMES_MODEL:=minimax/minimax-m2.7}"
HERMES_INFERENCE_PROVIDER="${HERMES_INFERENCE_PROVIDER:=openrouter}"
HERMES_GATEWAY_PORT="${HERMES_GATEWAY_PORT:=18790}"
HERMES_BACKGROUND_NOTIFICATIONS="${HERMES_BACKGROUND_NOTIFICATIONS:=result}"
GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:=false}"
DISCORD_ALLOWED_USERS="${DISCORD_ALLOWED_USERS:=588858125126336544}"
DISCORD_REQUIRE_MENTION="${DISCORD_REQUIRE_MENTION:=false}"
DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:=1484900474363842643}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:=}"
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:=}"

# Write .env at runtime
cat > "$HERMES_HOME/.env" << ENVEOF
HERMES_MODEL=${HERMES_MODEL}
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER}
HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT}
HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS}
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS}
DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS}
DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION}
DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}
ENVEOF
chown hermes:hermes "$HERMES_HOME/.env"

# Write config.yaml at runtime (model is already defaulted above)
printf 'model: "%s"\nfallback_providers: []\n' "$HERMES_MODEL" > "$HERMES_HOME/config.yaml"
chown hermes:hermes "$HERMES_HOME/config.yaml"

# Drop to hermes user via su and run hermes
# The .env file already has all defaults applied, so sourcing it is safe
exec su hermes -s /bin/bash << 'SUEOF'
set -e
cd /home/hermes
# Source .env to get all env vars (already has correct defaults baked in by root above)
. ~/.env
exec /opt/venv/bin/hermes gateway run
SUEOF
