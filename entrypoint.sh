#!/bin/bash
set -e

HERMES_DIR="${HERMES_HOME:-/home/hermes}/.hermes"

# Ensure hermes home is writable
chown -R hermes:hermes "$HERMES_DIR" 2>/dev/null || true
mkdir -p "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}
chown -R hermes:hermes "$HERMES_DIR"/{logs,sessions,memories,skills,cron,backups}

# Write .env (API keys and legacy vars)
{
    echo "# Generated at container start"
    for var in OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY MINIMAX_API_KEY \
               HERMES_INFERENCE_PROVIDER; do
        value="${!var}"
        if [ -n "$value" ]; then
            echo "${var}=${value}"
        fi
    done
} > "$HERMES_DIR/.env"

# Write config.yaml — model is a TOP-LEVEL STRING (not nested dict)
cat > "$HERMES_DIR/config.yaml" << 'CONFIG'
# Hermes Gateway Config
model: "openrouter:minimax/minimax-m2.7"
fallback_providers: []
credential_pool_strategies: {}
toolsets:
  - hermes-cli
agent:
  max_turns: 90
CONFIG

echo "✅ Hermes config ready at $HERMES_DIR/"
echo "--- .env ---"
cat "$HERMES_DIR/.env"
echo ""
echo "--- config.yaml ---"
cat "$HERMES_DIR/config.yaml"

exec hermes gateway
