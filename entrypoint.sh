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
DISCORD_ALLOW_BOTS="${DISCORD_ALLOW_BOTS:-all}"
DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"

# Write .env (hermes reads this via python-dotenv from $HERMES_CONFIG_DIR/.env)
cat > "$HERMES_CONFIG_DIR/.env" << ENVEOF
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER}
HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT}
HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS}
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS}
DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS}
DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION}
DISCORD_ALLOW_BOTS=${DISCORD_ALLOW_BOTS}
DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
# --- Bot Coordination ---
BOT_COORDINATION_DB_HOST=${BOT_COORDINATION_DB_HOST:-pg-nanachi}
BOT_COORDINATION_DB_PORT=${BOT_COORDINATION_DB_PORT:-5432}
BOT_COORDINATION_DB_USER=${BOT_COORDINATION_DB_USER:-postgres}
BOT_COORDINATION_DB_PASS=${BOT_COORDINATION_DB_PASS:-WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL}
BOT_COORDINATION_DB_NAME=${BOT_COORDINATION_DB_NAME:-projects}
# --- Marketing Director Tools ---
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY:-}
FALAI_API_KEY=${FALAI_API_KEY:-}
GH_TOKEN=${GH_TOKEN:-}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
POSTIZ_API_KEY=${POSTIZ_API_KEY:-}
POSTIZ_WEBHOOK_SECRET=${POSTIZ_WEBHOOK_SECRET:-}
MINIMAX_API_KEY=${MINIMAX_API_KEY:-}
CONTENT_REPO=${CONTENT_REPO:-https://github.com/yevgeniusr/content-studio}
ENVEOF

# Write config.yaml at the correct location: ~/.hermes/config.yaml
# This is where hermes reads the model from
cat > "$HERMES_CONFIG_DIR/config.yaml" << CFGEOF
model:
  default: "${HERMES_MODEL}"
  provider: "${HERMES_INFERENCE_PROVIDER}"
  base_url: "https://openrouter.ai/api/v1"
CFGEOF

chown -R hermes:hermes "$HERMES_CONFIG_DIR"

# ── Git credentials for push access ──────────────────────────────────────────
# GITHUB_TOKEN enables Hermess to push code/content changes to GitHub
if [ -n "$GITHUB_TOKEN" ]; then
    mkdir -p /home/hermes/.config/gh
    printf "protocol=https\nhost=github.com\nusername=git\npassword=%s\n" "$GITHUB_TOKEN" > /home/hermes/.config/gh/credentials
    chmod 600 /home/hermes/.config/gh/credentials
    git config --global credential.helper store
    git config --global credential.helper "store --file /home/hermes/.config/gh/credentials"
    echo "[OK] GitHub push access configured"
fi

# Run as hermes user
exec su hermes -c "
    export HOME=/home/hermes
    export HERMES_INFERENCE_PROVIDER='${HERMES_INFERENCE_PROVIDER}'
    export OPENROUTER_API_KEY='${OPENROUTER_API_KEY:-}'
    export DISCORD_BOT_TOKEN='${DISCORD_BOT_TOKEN:-}'
    cd /home/hermes

    # Start bot_coord listener as background daemon (real-time DB message processing)
    python3 bot_coord.py listen hermes &
    echo \"[hermes] bot_coord listener started (PID \$!)\"

    exec /opt/venv/bin/hermes gateway run
"
