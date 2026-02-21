# AGENTS.md

Guidelines for agentic coding agents working in this Docker Swarm operations repository.

## Project Overview

GitOps repository for managing Docker Swarm deployments with Traefik as reverse proxy, containing Traefik configuration, service definitions, deployment scripts, and GitLab CI/CD pipeline.

## Build/Lint/Test Commands

### Linting

```bash
yamllint -d relaxed .                           # Lint all YAML files
yamllint -d relaxed traefik/docker-compose.yml  # Lint specific file
shellcheck scripts/*.sh                         # Lint all shell scripts
shellcheck scripts/deploy.sh                    # Lint specific script
```

### Validation

```bash
./scripts/validate.sh                                                    # Validate all compose files
docker compose -f services/example-web/docker-compose.yml config --quiet # Validate single file
```

### Deployment

```bash
ENVIRONMENT=staging DOMAIN=staging.example.com ACME_EMAIL=admin@example.com ./scripts/deploy.sh
./scripts/deploy-traefik.sh                                              # Deploy Traefik only
docker stack deploy -c services/example-web/docker-compose.yml whoami    # Deploy single stack
docker stack rm whoami                                                   # Remove a stack
```

### Runtime Testing

```bash
docker service ls                       # List services
docker service logs traefik_traefik     # Check logs
docker service ps traefik_traefik       # Check tasks
```

## Code Style Guidelines

### Shell Scripts (Bash)

```bash
#!/bin/bash
set -e  # Always exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Variable naming: UPPER_CASE for env vars, lower_case for local
# Quote ALL expansions: "$VARIABLE" and "${VARIABLE}"

# Error handling pattern:
if [ -z "$REQUIRED_VAR" ]; then
    echo "Error: REQUIRED_VAR not set"
    exit 1
fi

# Idempotent operations:
docker network create --driver overlay traefik-public 2>/dev/null || true
[ ! -f "$FILE" ] && touch "$FILE" && chmod 600 "$FILE"
```

### YAML Files

**Formatting:** 2-space indentation, max 120 characters per line

**docker-compose.yml structure:**
```yaml
version: "3.8"

services:
  app:  # Use 'app' for generic service or descriptive name
    image: image:tag
    networks:
      - traefik-public
    deploy:
      mode: replicated
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
    healthcheck:
      test: ["CMD", "healthcheck-command"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik-public:
    external: true
```

**GitLab CI:** Job names use `stage:action` format (e.g., `lint:yaml`, `deploy:staging`). Use `rules` instead of `only/except`.

### Traefik Labels

Required labels for each service (replace `<name>` with unique router/service name):
```yaml
- "traefik.enable=true"
- "traefik.http.routers.<name>.rule=Host(`subdomain.${DOMAIN}`)"
- "traefik.http.routers.<name>.entrypoints=websecure"
- "traefik.http.routers.<name>.tls=true"
- "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
- "traefik.http.services.<name>.loadbalancer.server.port=8080"
```

**Middleware chaining:** `"security-headers@file,rate-limit@file"`
**Naming convention:** Router/service names match the service; middleware refs use `name@file`

### File Naming

- Directories: `kebab-case`
- Scripts: `kebab-case.sh`
- YAML: `kebab-case.yml`
- Environment: `.env` or `.env.example`

### Environment Variables

**Required:** `ACME_EMAIL`, `DOMAIN`, `BASIC_AUTH_USER`, `BASIC_AUTH_HASH`
**In compose files:** `${VARIABLE:-default}` for optional, `${VARIABLE}` for required

### Git Commits

Format: `type(scope): description` (types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`)

## Critical Patterns

1. **Never commit `.env` files** - Use `.env.example` templates only
2. **Always `set -e`** in scripts - Exit on first error
3. **Quote all expansions** - `"${VARIABLE}"` not `$VARIABLE`
4. **Use `|| true`** for idempotent operations that may fail
5. **Validate variables early** - Check prerequisites at script start
6. **Traefik on manager nodes** - `node.role == manager` placement constraint
7. **Health checks required** - Every service needs a healthcheck block

## Common Tasks

**Add a new service:**
1. Create `services/my-service/docker-compose.yml`
2. Add Traefik labels with unique router name
3. Validate: `docker compose -f services/my-service/docker-compose.yml config`
4. Commit - GitLab CI validates and deploys

**Add/modify middleware:**
1. Edit `traefik/dynamic/middlewares.yml`
2. Add under `http.middlewares`
3. Reference in service: `middleware-name@file` (hot reload, no restart needed)

**Traefik configuration changes:**
- Static config (`traefik.yml`): requires `docker stack deploy` restart
- Dynamic config (`dynamic/*.yml`): hot reloads automatically
