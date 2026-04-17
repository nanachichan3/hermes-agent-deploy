#!/bin/bash
# browser-sidecar.sh — Start Chrome with AIO extension + remote debugging
# Used as entrypoint for the browser sidecar container
set -e

AIO_DIR="${AIO_DIR:-/opt/aio}"
CHROME_TOKEN="${CHROME_TOKEN:-hermes2026}"
CDP_PORT="${CDP_PORT:-9222}"

# Find Chrome binary
CHROME_BIN=$(which google-chrome || which chromium-browser || which chromium || echo "/usr/bin/google-chrome")

echo "[browser-sidecar] Starting Chrome with AIO extension..."
echo "[browser-sidecar] AIO_DIR=$AIO_DIR, CDP_PORT=$CDP_PORT, TOKEN=$CHROME_TOKEN"

# Build Chrome launch args
# --remote-debugging-port: Expose CDP at :9222
# --load-extension: Load AIO from /opt/aio
# CHROME_TOKEN env var can be checked by the extension for auth
CHROME_ARGS=(
    "--remote-debugging-port=${CDP_PORT}"
    "--load-extension=${AIO_DIR}"
    "--disable-dev-shm-usage"
    "--no-sandbox"
    "--disable-gpu"
    "--disable-setuid-sandbox"
    "--disable-web-security"
    "--user-data-dir=/tmp/chrome-user-data"
    "--lang=en-US"
)

echo "[browser-sidecar] Chrome args: ${CHROME_ARGS[*]}"

# Launch Chrome (blocking)
exec "$CHROME_BIN" "${CHROME_ARGS[@]}"
