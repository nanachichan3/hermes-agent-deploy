#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"
HERMES_DIR="$HERMES_HOME"  # config.yaml goes to $HERMES_HOME (not $HERMES_HOME/.hermes)

# Ensure hermes home is writable
chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true
mkdir -p "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME"/{sessions,memories,skills,cron,backups}
# Also create .hermes subdir for backwards compatibility
mkdir -p "$HERMES_HOME/.hermes"/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_HOME/.hermes"/{logs,sessions,memories,skills,cron,backups}

# Write .env to $HERMES_HOME/.env
{
    echo "# Generated at container start"
    for var in OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY MINIMAX_API_KEY \
               HERMES_INFERENCE_PROVIDER; do
        value="${!var}"
        if [ -n "$value" ]; then
            echo "${var}=${value}"
        fi
    done
} > "$HERMES_HOME/.env"

# Write config.yaml to $HERMES_HOME/config.yaml (where hermes expects it!)
cat > "$HERMES_HOME/config.yaml" << 'CONFIG'
# Hermes Gateway Config
model: "openrouter:minimax/minimax-m2.7"
fallback_providers: []
credential_pool_strategies: {}
toolsets:
  - hermes-cli
agent:
  max_turns: 90
discord:
  require_mention: false
  free_response_channels: "1484900474363842643"
CONFIG

echo "✅ Hermes config ready at $HERMES_HOME/"
echo "--- $HERMES_HOME/.env ---"
cat "$HERMES_HOME/.env"
echo ""
echo "--- $HERMES_HOME/config.yaml ---"
cat "$HERMES_HOME/config.yaml"

exec hermes gateway
