FROM python:3.11-slim

ARG OPENROUTER_API_KEY
ARG DISCORD_BOT_TOKEN

# Install system deps + uv + opus (for Discord voice)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential libopus0 libopus-dev \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

# Create hermes user
RUN useradd -m -s /bin/bash --uid 1000 hermes

# Pre-create hermes home structure
RUN mkdir -p /home/hermes/.hermes/{logs,sessions,memories,skills,cron,backups} && \
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
