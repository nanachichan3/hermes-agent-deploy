# Build arg for model - force docker to not use cache for the RUN that uses it
ARG HERMES_MODEL_ARG=minimax/minimax-m2.7

FROM python:3.11-slim

ARG HERMES_MODEL_ARG

# Install system deps + uv + opus (for Discord voice)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential libopus0 libopus-dev \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

# Create hermes user
RUN useradd -m -s /bin/bash --uid 1000 hermes

# Create hermes home
RUN mkdir -p /home/hermes && chown hermes:hermes /home/hermes

# Install gosu for clean privilege drop (preserves all env vars unlike su)
RUN curl -LsSf https://github.com/tianon/gosu/releases/download/1.23/gosu-amd64 -o /usr/local/bin/gosu \
    && chmod +x /usr/local/bin/gosu

# Install hermes-agent from GitHub (all extras)
RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python \
        "git+https://github.com/NousResearch/hermes-agent[messaging,cron,cli,honcho]"

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
    echo "DISCORD_FREE_RESPONSE_CHANNELS=1484900474363842643" >> /home/hermes/.env && \
    chown hermes:hermes /home/hermes/.env

# Pre-write config.yaml at build time
RUN echo 'model: "minimax/minimax-m2.7"' > /home/hermes/config.yaml && \
    echo 'fallback_providers: []' >> /home/hermes/config.yaml && \
    chown hermes:hermes /home/hermes/config.yaml

# Copy entrypoint and SOUL.md (baked into image - prevents directory mismatch with volumes)
COPY entrypoint.sh /entrypoint.sh
COPY SOUL.md /home/hermes/SOUL.md
RUN chmod +x /entrypoint.sh && chown hermes:hermes /home/hermes/SOUL.md

WORKDIR /home/hermes

ENTRYPOINT ["/entrypoint.sh"]
