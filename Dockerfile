FROM python:3.11-slim

ARG OPENROUTER_API_KEY
ARG DISCORD_BOT_TOKEN

# Install system deps + uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

# Create hermes user (matching uid/gid to docker volume default)
RUN useradd -m -s /bin/bash --uid 1000 hermes

# Create hermes home and write .env at build time
RUN mkdir -p /home/hermes/.hermes && \
    echo "# Auto-generated at build time" > /home/hermes/.hermes/.env && \
    echo "HERMES_MODEL=openrouter:minimax/minimax-m2.7" >> /home/hermes/.hermes/.env && \
    echo "HERMES_GATEWAY_PORT=18790" >> /home/hermes/.hermes/.env && \
    echo "HERMES_BACKGROUND_NOTIFICATIONS=result" >> /home/hermes/.hermes/.env && \
    echo "GATEWAY_ALLOW_ALL_USERS=false" >> /home/hermes/.hermes/.env && \
    echo "DISCORD_ALLOWED_USERS=588858125126336544" >> /home/hermes/.hermes/.env && \
    echo "DISCORD_REQUIRE_MENTION=false" >> /home/hermes/.hermes/.env && \
    echo "DISCORD_FREE_RESPONSE_CHANNELS=1484900474363842643" >> /home/hermes/.hermes/.env && \
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}" >> /home/hermes/.hermes/.env && \
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}" >> /home/hermes/.hermes/.env && \
    mkdir -p /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups} && \
    chown -R hermes:hermes /home/hermes/.hermes

# Install hermes-agent from GitHub (all extras)
RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python \
        "git+https://github.com/NousResearch/hermes-agent[messaging,cron,cli,honcho]"

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Mount point for persistent data
VOLUME ["/home/hermes/.hermes"]

WORKDIR /home/hermes

ENTRYPOINT ["/entrypoint.sh"]
