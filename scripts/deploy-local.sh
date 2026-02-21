#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Local Development Deployment (Docker Swarm) ==="

echo "Creating traefik-public overlay network..."
docker network create --driver overlay --attachable traefik-public 2>/dev/null || true

echo "Deploying Traefik..."
docker stack deploy -c "${PROJECT_ROOT}/traefik/docker-compose-local.yml" traefik

echo "Waiting for Traefik to start..."
sleep 5

echo ""
echo "=== Traefik deployed successfully! ==="
echo "Dashboard: http://127.0.0.1:8080"
echo ""
echo "To deploy a test service:"
echo "  docker stack deploy -c services/local/docker-compose.yml local-whoami"
echo ""
echo "Then access: http://whoami.localtest.me"