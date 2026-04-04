#!/bin/bash
set -e

# Use HERMES_HOME if set, otherwise default to /home/hermes
HERMES_DIR="${HERMES_HOME:-/home/hermes}/.hermes"

# Ensure hermes home is writable
chown -R hermes:hermes "$HERMES_DIR" 2>/dev/null || true
mkdir -p "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}

# Write .env from runtime environment only (skip empty values)
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

echo "✅ Hermes .env ready at $HERMES_DIR/.env:"
cat "$HERMES_DIR/.env"

exec hermes gateway
