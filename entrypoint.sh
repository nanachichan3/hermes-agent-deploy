#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"
HERMES_CONFIG_DIR="$HERMES_HOME/.hermes"

# Ensure required dirs exist
mkdir -p "$HERMES_CONFIG_DIR"/{sessions,memories,skills,cron,backups}

# ============================================================
# Apply defaults for vars that might be empty strings from Coolify
# ============================================================
if [ -z "$HERMES_MODEL" ]; then
    HERMES_MODEL="minimax/minimax-m2.7"
fi
if [ -z "$HERMES_INFERENCE_PROVIDER" ]; then
    HERMES_INFERENCE_PROVIDER="openrouter"
fi
HERMES_GATEWAY_PORT="${HERMES_GATEWAY_PORT:-18790}"
HERMES_BACKGROUND_NOTIFICATIONS="${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:-false}"
DISCORD_ALLOWED_USERS="${DISCORD_ALLOWED_USERS:-588858125126336544}"
DISCORD_REQUIRE_MENTION="${DISCORD_REQUIRE_MENTION:-false}"
DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"

# Write debug log
{
    echo "HERMES_MODEL=$HERMES_MODEL"
    echo "HERMES_INFERENCE_PROVIDER=$HERMES_INFERENCE_PROVIDER"
    echo "HERMES_CONFIG_DIR=$HERMES_CONFIG_DIR"
} > "$HERMES_HOME/entrypt.log"

# Write .env (hermes reads this via python-dotenv from $HERMES_CONFIG_DIR/.env)
cat > "$HERMES_CONFIG_DIR/.env" << ENVEOF
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER}
HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT}
HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS}
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS}
DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS}
DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION}
DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
ENVEOF

# Write config.yaml at the correct location: ~/.hermes/config.yaml
# This is where hermes reads the model from
cat > "$HERMES_CONFIG_DIR/config.yaml" << CFGEOF
model:
  default: "${HERMES_MODEL}"
  fallback_providers: []
inference:
  provider: "${HERMES_INFERENCE_PROVIDER}"
CFGEOF

chown -R hermes:hermes "$HERMES_HOME"
chown -R hermes:hermes "$HERMES_CONFIG_DIR"

# Run as hermes user
exec su hermes -c "
    export HOME=/home/hermes
    export HERMES_INFERENCE_PROVIDER='${HERMES_INFERENCE_PROVIDER}'
    export OPENROUTER_API_KEY='${OPENROUTER_API_KEY:-}'
    export DISCORD_BOT_TOKEN='${DISCORD_BOT_TOKEN:-}'
    cd /home/hermes
    exec /opt/venv/bin/hermes gateway run
"
