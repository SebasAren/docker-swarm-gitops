#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Copy .env.example to .env and configure it."
    exit 1
fi

source "$ENV_FILE"

if [ -z "$ACME_EMAIL" ]; then
    echo "Error: ACME_EMAIL not set in .env"
    exit 1
fi

echo "Creating traefik-public overlay network..."
docker network create --driver overlay --attachable traefik-public 2>/dev/null || true

echo "Creating acme.json if it doesn't exist..."
ACME_FILE="${PROJECT_ROOT}/traefik/acme.json"
if [ ! -f "$ACME_FILE" ]; then
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
fi

echo "Deploying Traefik stack..."
docker stack deploy -c "${PROJECT_ROOT}/traefik/docker-compose.yml" traefik

echo "Waiting for Traefik to start..."
sleep 5

echo "Traefik deployed successfully!"
echo "Dashboard available at: http://127.0.0.1:8080"