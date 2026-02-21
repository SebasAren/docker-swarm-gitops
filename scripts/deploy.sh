#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT="${ENVIRONMENT:-staging}"
DOMAIN="${DOMAIN:-}"

if [ -z "$DOMAIN" ]; then
    echo "Error: DOMAIN variable not set"
    exit 1
fi

if [ -z "$ACME_EMAIL" ]; then
    echo "Error: ACME_EMAIL variable not set"
    exit 1
fi

echo "=== Deploying to $ENVIRONMENT ==="
echo "Domain: $DOMAIN"
echo "ACME Email: $ACME_EMAIL"

ENV_DIR="${PROJECT_ROOT}/environments/${ENVIRONMENT}"
mkdir -p "$ENV_DIR"

ENV_FILE="${ENV_DIR}/.env"
cat > "$ENV_FILE" << EOF
ACME_EMAIL=${ACME_EMAIL}
DOMAIN=${DOMAIN}
BASIC_AUTH_USER=${BASIC_AUTH_USER:-admin}
BASIC_AUTH_HASH=${BASIC_AUTH_HASH:-}
EOF

chmod 600 "$ENV_FILE"

source "$ENV_FILE"

echo "Creating traefik-public overlay network..."
docker network create --driver overlay --attachable traefik-public 2>/dev/null || true

ACME_FILE="${PROJECT_ROOT}/traefik/acme.json"
if [ ! -f "$ACME_FILE" ]; then
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
fi

echo "Deploying Traefik..."
docker stack deploy -c "${PROJECT_ROOT}/traefik/docker-compose.yml" traefik

echo "Waiting for Traefik to be ready..."
sleep 10

for service_dir in "$PROJECT_ROOT"/services/*/; do
    service_name=$(basename "$service_dir")
    compose_file="${service_dir}docker-compose.yml"
    if [ -f "$compose_file" ]; then
        echo "Deploying service: $service_name"
        docker stack deploy -c "$compose_file" --with-registry-auth "$service_name" || true
    fi
done

echo ""
echo "=== Deployment to $ENVIRONMENT complete ==="
docker service ls