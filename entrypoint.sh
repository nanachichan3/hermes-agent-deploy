#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}

# ============================================================
# Step 1: Resolve HERMES_MODEL with defaults FIRST
# Use := to catch both unset AND empty-string values
# This is the PRIMARY fix for "No models provided" error
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

# Debug: log resolved env vars to a file in the volume
{
    echo "=== Entrypoint Debug ==="
    echo "HERMES_MODEL=$HERMES_MODEL"
    echo "HERMES_INFERENCE_PROVIDER=$HERMES_INFERENCE_PROVIDER"
    echo "HERMES_GATEWAY_PORT=$HERMES_GATEWAY_PORT"
    echo "PWD=$(pwd)"
    echo "========================"
} > "$HERMES_HOME/entrypt.log"

# ============================================================
# Step 2: Write .env for hermes (with explicit model value)
# ============================================================
cat > "$HERMES_HOME/.env" << ENVEOF
HERMES_MODEL=${HERMES_MODEL}
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

# ============================================================
# Step 3: Write config.yaml with the resolved model
# ============================================================
cat > "$HERMES_HOME/config.yaml" << CFGEOF
model: "${HERMES_MODEL}"
fallback_providers: []
CFGEOF

chown -R hermes:hermes "$HERMES_HOME"

# ============================================================
# Step 4: Drop to hermes user and run
# Use su exec pattern that passes vars explicitly
# ============================================================
exec su hermes -c "
    export HERMES_MODEL='${HERMES_MODEL}'
    export HERMES_INFERENCE_PROVIDER='${HERMES_INFERENCE_PROVIDER}'
    export HERMES_GATEWAY_PORT='${HERMES_GATEWAY_PORT}'
    export HERMES_BACKGROUND_NOTIFICATIONS='${HERMES_BACKGROUND_NOTIFICATIONS}'
    export GATEWAY_ALLOW_ALL_USERS='${GATEWAY_ALLOW_ALL_USERS}'
    export DISCORD_ALLOWED_USERS='${DISCORD_ALLOWED_USERS}'
    export DISCORD_REQUIRE_MENTION='${DISCORD_REQUIRE_MENTION}'
    export DISCORD_FREE_RESPONSE_CHANNELS='${DISCORD_FREE_RESPONSE_CHANNELS}'
    export OPENROUTER_API_KEY='${OPENROUTER_API_KEY:-}'
    export DISCORD_BOT_TOKEN='${DISCORD_BOT_TOKEN:-}'
    /opt/venv/bin/hermes gateway run
"
