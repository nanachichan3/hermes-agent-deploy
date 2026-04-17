# Build arg for model - force docker to not use cache for the RUN that uses it
ARG HERMES_MODEL_ARG=minimax/minimax-m2.7

FROM python:3.11-slim

ARG HERMES_MODEL_ARG

# Install system deps + uv + opus (for Discord voice)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential libopus0 libopus-dev unzip \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

# Create hermes user
RUN useradd -m -s /bin/bash --uid 1000 hermes

# Create hermes home
RUN mkdir -p /home/hermes && chown hermes:hermes /home/hermes

# Install hermes-agent from GitHub (all extras) + psycopg2 for bot coordination
RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python \
        "git+https://github.com/NousResearch/hermes-agent[messaging,cron,cli,honcho]" \
        psycopg2-binary

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Pre-write the .env file at build time with the model (prevents cached layer issues)
RUN echo "# Build-time config" > /home/hermes/.env && \
    echo "HERMES_MODEL=${HERMES_MODEL_ARG}" >> /home/hermes/.env && \
    echo "HERMES_INFERENCE_PROVIDER=openrouter" >> /home/hermes/.env && \
    echo "HERMES_GATEWAY_PORT=18790" >> /home/hermes/.env && \
    echo "HERMES_BACKGROUND_NOTIFICATIONS=result" >> /home/hermes/.env && \
    echo "GATEWAY_ALLOW_ALL_USERS=false" >> /home/hermes/.env && \
    echo "DISCORD_ALLOWED_USERS=588858125126336544" >> /home/hermes/.env && \
    echo "DISCORD_REQUIRE_MENTION=false" >> /home/hermes/.env && \
    echo "DISCORD_ALLOW_BOTS=all" >> /home/hermes/.env && \
    echo "DISCORD_FREE_RESPONSE_CHANNELS=1484900474363842643" >> /home/hermes/.env && \
    echo "ELEVENLABS_API_KEY=" >> /home/hermes/.env && \
    echo "FALAI_API_KEY=" >> /home/hermes/.env && \
    echo "GH_TOKEN=" >> /home/hermes/.env && \
    echo "POSTIZ_API_KEY=" >> /home/hermes/.env && \
    echo "POSTIZ_WEBHOOK_SECRET=" >> /home/hermes/.env && \
    echo "MINIMAX_API_KEY=" >> /home/hermes/.env && \
    echo "CONTENT_REPO=https://github.com/yevgeniusr/content-studio" >> /home/hermes/.env && \
    chown hermes:hermes /home/hermes/.env

# Configure git with GitHub token for push access
# Token is passed at runtime via GITHUB_TOKEN env var


# Pre-write config.yaml at build time
RUN echo 'model: "minimax/minimax-m2.7"' > /home/hermes/config.yaml && \
    echo 'fallback_providers: []' >> /home/hermes/config.yaml && \
    chown hermes:hermes /home/hermes/config.yaml

# Install AIO (All-In-One) browser extension for CDP browser automation
ARG AIO_VERSION=1.2.1
RUN curl -sL "https://github.com/kimfindly/AIO/releases/download/v${AIO_VERSION}/AIO.zip" -o /tmp/aio.zip && \
    unzip -q /tmp/aio.zip -d /opt/aio && \
    rm /tmp/aio.zip && \
    echo "[OK] AIO v${AIO_VERSION} installed at /opt/aio"

# Copy entrypoint and SOUL.md (baked into image - prevents directory mismatch with volumes)
COPY entrypoint.sh /entrypoint.sh
COPY SOUL.md /home/hermes/SOUL.md
COPY bot_coord.py /home/hermes/bot_coord.py
COPY skills/ /home/hermes/skills/
RUN chmod +x /entrypoint.sh && chown hermes:hermes /home/hermes/SOUL.md /home/hermes/bot_coord.py

WORKDIR /home/hermes

ENTRYPOINT ["/entrypoint.sh"]
