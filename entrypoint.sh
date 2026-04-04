#!/bin/bash
set -e

# Ensure hermes home is writable
chown -R hermes:hermes /home/hermes/.hermes 2>/dev/null || true
mkdir -p /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups}

# Write .env from runtime environment (overrides any build-time values)
cat > /home/hermes/.hermes/.env << 'ENVS'
# Generated at container start from environment
ENVS

# Append all relevant env vars
for var in HERMES_MODEL HERMES_MODEL_OPENROUTER HERMES_GATEWAY_PORT \
           HERMES_BACKGROUND_NOTIFICATIONS GATEWAY_ALLOW_ALL_USERS \
           DISCORD_ALLOWED_USERS DISCORD_REQUIRE_MENTION \
           DISCORD_FREE_RESPONSE_CHANNELS DISCORD_BOT_TOKEN \
           OPENROUTER_API_KEY OPENROUTER_API_KEY \
           ANTHROPIC_API_KEY OPENAI_API_KEY MINIMAX_API_KEY; do
    if [ -n "${!var}" ]; then
        echo "${var}=${!var}" >> /home/hermes/.hermes/.env
    fi
done

# Always ensure HERMES_MODEL is set
if ! grep -q "HERMES_MODEL=" /home/hermes/.hermes/.env; then
    echo "HERMES_MODEL=openrouter:minimax/minimax-m2.7" >> /home/hermes/.hermes/.env
fi

echo "✅ Hermes .env ready:"
cat /home/hermes/.hermes/.env

exec hermes gateway
