# syntax=docker/dockerfile:1

# This Dockerfile is designed for production, not development. For local
# dev, run directly: cp .env.example .env && uv sync && uv run godslayer-ml

# Make sure PYTHON_VERSION matches the version in .python-version
ARG PYTHON_VERSION=3.14.7
FROM python:${PYTHON_VERSION}-slim AS base

WORKDIR /app

# tesseract-ocr is the real OCR binary pytesseract wraps - not a pure-Python
# dependency, has to be installed on the image itself.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y tesseract-ocr && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Throw-away build stage to keep the uv cache out of the final image
FROM base AS build

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY . .
RUN uv sync --locked --no-dev

# Final stage for the app image
FROM base

# Run and own only the runtime files as a non-root user for security -
# same uid/gid as the Rails image, for consistency, not because it matters.
RUN groupadd --system --gid 1000 godslayer && \
    useradd godslayer --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=godslayer:godslayer --from=build /app /app

ENV PATH="/app/.venv/bin:$PATH"

CMD ["godslayer-ml"]
