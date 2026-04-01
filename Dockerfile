# syntax=docker/dockerfile:1
FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1 \
    BACKEND_HOST=0.0.0.0 \
    BACKEND_PORT=8080 \
    BACKEND_DB_FILE=/app/data/treehole.db \
    BACKEND_STORAGE_DIR=/app/storage/objects \
    BACKEND_WEB_ROOT=/app/web \
    BACKEND_OBJECT_STORAGE_BACKEND=local \
    BACKEND_ALLOW_DEBUG_VERIFY_CODE=false \
    BACKEND_INCLUDE_DEBUG_CODE=false

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY backend/requirements*.txt /app/
RUN pip install --no-cache-dir -r backend/requirements-storage.txt 2>/dev/null \
    || pip install --no-cache-dir boto3

# Copy backend code
COPY backend/ /app/backend/

# Create data and storage directories
RUN mkdir -p /app/data /app/storage/objects

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/api/channels || exit 1

EXPOSE 8080

CMD ["python3", "backend/server.py"]
