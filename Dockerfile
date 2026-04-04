FROM python:3.11-slim

# Install system deps + uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Put uv on PATH
ENV PATH="/root/.local/bin:$PATH"

# Create venv and install hermes-agent from GitHub (all extras)
RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python \
        "git+https://github.com/NousResearch/hermes-agent[messaging,cron,cli,honcho]"

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create hermes user
RUN useradd -m -s /bin/bash hermes

# Copy and set up entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Mount point for persistent data (sessions, memory, skills all persist here)
VOLUME ["/home/hermes/.hermes"]

WORKDIR /home/hermes

ENTRYPOINT ["/entrypoint.sh"]
# Default CMD - overridden by docker-compose command
CMD ["hermes", "gateway", "start"]
