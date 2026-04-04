FROM python:3.11-slim

# Install system deps + uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Put uv on PATH
ENV PATH="/root/.local/bin:$PATH"

# Install hermes-agent with messaging + cron extras
RUN uv venv /opt/venv --python 3.11
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install hermes-agent[messaging,cron,cli,honcho]
RUN uv pip install "hermes-agent[messaging,cron,cli,honcho]" --python /opt/venv

# Create hermes user for non-root运行
RUN useradd -m -s /bin/bash hermes

# Mount point for persistent data
VOLUME ["/home/hermes/.hermes"]

WORKDIR /home/hermes

# Default: start gateway (can be overridden by Coolify command)
CMD ["hermes", "gateway", "start"]
