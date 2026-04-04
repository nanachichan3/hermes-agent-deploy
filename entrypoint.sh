#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"

# Ensure required dirs exist with correct permissions
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true

# Apply defaults FIRST — before any env vars are used or exported
# This catches Coolify passing HERMES_MODEL="" (empty string) explicitly
HERMES_MODEL="${HERMES_MODEL:-minimax/minimax-m2.7}"
HERMES_INFERENCE_PROVIDER="${HERMES_INFERENCE_PROVIDER:-openrouter}"
HERMES_GATEWAY_PORT="${HERMES_GATEWAY_PORT:-18790}"
HERMES_BACKGROUND_NOTIFICATIONS="${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:-false}"
DISCORD_ALLOWED_USERS="${DISCORD_ALLOWED_USERS:-588858125126336544}"
DISCORD_REQUIRE_MENTION="${DISCORD_REQUIRE_MENTION:-false}"
DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"

# Write .env at runtime (hermes reads it)
cat > "$HERMES_HOME/.env" << 'ENVEOF'
# Hermes Agent - generated at container start
ENVEOF
echo "HERMES_MODEL=${HERMES_MODEL}" >> "$HERMES_HOME/.env"
echo "HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER}" >> "$HERMES_HOME/.env"
echo "HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT}" >> "$HERMES_HOME/.env"
echo "HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS}" >> "$HERMES_HOME/.env"
echo "GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS}" >> "$HERMES_HOME/.env"
echo "DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS}" >> "$HERMES_HOME/.env"
echo "DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION}" >> "$HERMES_HOME/.env"
echo "DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS}" >> "$HERMES_HOME/.env"
echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}" >> "$HERMES_HOME/.env"
echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}" >> "$HERMES_HOME/.env"
chown hermes:hermes "$HERMES_HOME/.env"

# Write config.yaml at runtime
cat > "$HERMES_HOME/config.yaml" << CFGEOF
model: "${HERMES_MODEL}"
fallback_providers: []
CFGEOF
chown hermes:hermes "$HERMES_HOME/config.yaml"

# Use gosu for clean privilege drop (preserves all env vars as-is)
# Fall back to su if gosu is not available
if [ -x /usr/local/bin/gosu ]; then
    exec /usr/local/bin/gosu hermes /opt/venv/bin/hermes gateway run
elif command -v gosu >/dev/null 2>&1; then
    exec gosu hermes /opt/venv/bin/hermes gateway run
else
    # su with no complex quoting - just inherit exported vars from this shell
    # Run a minimal shell as hermes that sources .env and execs hermes
    exec su hermes -s /bin/bash << 'SUEOF'
set -e
# Inherit all env from parent (already has defaults applied above)
cd /home/hermes
. ~/.env
exec /opt/venv/bin/hermes gateway run
SUEOF
fi
