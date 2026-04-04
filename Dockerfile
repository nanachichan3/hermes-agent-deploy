FROM python:3.11-slim

# Install system deps + uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Put uv on PATH
ENV PATH="/root/.local/bin:$PATH"

# Create hermes user before installing (good practice for non-root)
RUN useradd -m -s /bin/bash hermes

# Install hermes-agent from GitHub with all extras
RUN su - hermes -c "\
    uv venv /home/hermes/.hermes/venv --python 3.11 && \
    uv pip install --python /home/hermes/.hermes/venv/bin/python \
        'hermes-agent[messaging,cron,cli,honcho]'"

ENV VIRTUAL_ENV=/home/hermes/.hermes/venv
ENV PATH="/home/hermes/.hermes/venv/bin:$PATH"

# Mount point for persistent data
VOLUME ["/home/hermes/.hermes"]

WORKDIR /home/hermes

# Default: start gateway
CMD ["hermes", "gateway", "start"]
