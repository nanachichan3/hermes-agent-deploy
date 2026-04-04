#!/bin/bash
set -e

# Ensure hermes home is writable
chown -R hermes:hermes /home/hermes/.hermes 2>/dev/null || true
mkdir -p /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}

# Write .env from runtime environment only (skip empty values)
{
    echo "# Generated at container start from environment"
    for var in HERMES_MODEL HERMES_GATEWAY_PORT HERMES_BACKGROUND_NOTIFICATIONS \
               GATEWAY_ALLOW_ALL_USERS \
               DISCORD_ALLOWED_USERS DISCORD_REQUIRE_MENTION \
               DISCORD_FREE_RESPONSE_CHANNELS \
               OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY MINIMAX_API_KEY; do
        value="${!var}"
        if [ -n "$value" ]; then
            echo "${var}=${value}"
        fi
    done
} > /home/hermes/.hermes/.env

echo "✅ Hermes .env ready:"
cat /home/hermes/.hermes/.env

exec hermes gateway
