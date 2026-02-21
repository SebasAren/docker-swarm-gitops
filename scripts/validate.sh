#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Validating Docker Compose files ==="

validate_compose() {
    local compose_file="$1"
    if [ -f "$compose_file" ]; then
        echo "Validating: $compose_file"
        docker compose -f "$compose_file" config --quiet
        echo "✓ $compose_file is valid"
    fi
}

for compose_file in "$PROJECT_ROOT"/traefik/docker-compose.yml \
                     "$PROJECT_ROOT"/services/*/docker-compose.yml; do
    if [ -f "$compose_file" ]; then
        validate_compose "$compose_file"
    fi
done

echo ""
echo "=== All validations passed ==="