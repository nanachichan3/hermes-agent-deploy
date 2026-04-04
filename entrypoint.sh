#!/bin/bash
set -e

HERMES_DIR="${HERMES_HOME:-/home/hermes}/.hermes"

# Ensure hermes home is writable
chown -R hermes:hermes "$HERMES_DIR" 2>/dev/null || true
mkdir -p "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}

# Write .env (legacy support)
{
    echo "# Generated at container start"
    for var in HERMES_MODEL HERMES_HOME HERMES_GATEWAY_PORT HERMES_BACKGROUND_NOTIFICATIONS \
               GATEWAY_ALLOW_ALL_USERS \
               DISCORD_ALLOWED_USERS DISCORD_REQUIRE_MENTION \
               DISCORD_FREE_RESPONSE_CHANNELS \
               OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY MINIMAX_API_KEY; do
        value="${!var}"
        if [ -n "$value" ]; then
            echo "${var}=${value}"
        fi
    done
} > "$HERMES_DIR/.env"

# Write config.yaml (primary config that gateway actually reads)
cat > "$HERMES_DIR/config.yaml" << 'CONFIG'
# Hermes Gateway Config
model:
  provider: openrouter
  default: minimax/minimax-m2.7

gateway:
  port: 18790
  allow_all_users: false

discord:
  allowed_users:
    - "588858125126336544"
  require_mention: false
  free_response_channels:
    - "1484900474363842643"
CONFIG

echo "✅ Hermes config ready at $HERMES_DIR/"
echo "--- .env ---"
cat "$HERMES_DIR/.env"
echo ""
echo "--- config.yaml ---"
cat "$HERMES_DIR/config.yaml"

exec hermes gateway
