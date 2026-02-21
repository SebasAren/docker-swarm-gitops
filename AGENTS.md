# AGENTS.md

Guidelines for agentic coding agents working in this Docker Swarm operations repository.

## Project Overview

GitOps repository for managing Docker Swarm deployments with Traefik as reverse proxy, containing Traefik configuration, service definitions, deployment scripts, and GitLab CI/CD pipeline.

## Build/Lint/Test Commands

### Linting

```bash
# Lint all YAML files
yamllint -d relaxed .

# Lint a specific YAML file
yamllint -d relaxed traefik/docker-compose.yml

# Lint all shell scripts
shellcheck scripts/*.sh
```

### Validation

```bash
# Validate all docker-compose files
./scripts/validate.sh

# Validate a specific compose file
docker compose -f services/example-web/docker-compose.yml config --quiet
```

### Deployment

```bash
# Deploy to staging
ENVIRONMENT=staging DOMAIN=staging.example.com ACME_EMAIL=admin@example.com ./scripts/deploy.sh

# Deploy to production
ENVIRONMENT=production DOMAIN=example.com ACME_EMAIL=admin@example.com ./scripts/deploy.sh

# Deploy Traefik only
./scripts/deploy-traefik.sh

# Deploy a single service stack
docker stack deploy -c services/example-web/docker-compose.yml whoami

# Remove a stack
docker stack rm whoami
```

### Testing Services

```bash
docker service ls                                    # List services
docker service logs traefik_traefik                  # Check logs
docker service ps traefik_traefik                    # Check tasks
```

## Code Style Guidelines

### Shell Scripts (Bash)

**Shebang and Settings:**
```bash
#!/bin/bash
set -e  # Always exit on error
```

**Variable naming:**
- `UPPER_CASE` for environment variables
- `lower_case` for local variables
- Quote all expansions: `"$VARIABLE"`

**Script structure:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
```

**Error handling:**
```bash
if [ -z "$REQUIRED_VAR" ]; then
    echo "Error: REQUIRED_VAR not set"
    exit 1
fi
```

**Idempotent operations:**
```bash
docker network create --driver overlay traefik-public 2>/dev/null || true
[ ! -f "$FILE" ] && touch "$FILE" && chmod 600 "$FILE"
```

### YAML Files

**Indentation:** 2 spaces, max line length 120 characters

**docker-compose.yml structure:**
```yaml
version: "3.8"

services:
  service_name:
    image: image:tag
    networks:
      - traefik-public
    deploy:
      mode: replicated
      replicas: 2
      labels:
        - "traefik.enable=true"
    healthcheck:
      test: ["CMD", "command", "arg"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik-public:
    external: true
```

**GitLab CI YAML:**
- Job names: `stage:action` format (e.g., `lint:yaml`, `deploy:staging`)
- Extend templates from `.gitlab/ci/templates.yml`
- Use `rules` instead of `only/except`

### Traefik Labels

**Required labels:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`subdomain.${DOMAIN}`)"
  - "traefik.http.routers.<name>.entrypoints=websecure"
  - "traefik.http.routers.<name>.tls=true"
  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
  - "traefik.http.services.<name>.loadbalancer.server.port=8080"
```

**Middleware chaining:** `"security-headers@file,rate-limit@file"`

**Naming:** Router/Traefik service names match the service name; middleware refs use `name@file`

### Docker Compose Conventions

- Service name: `app` (generic) or descriptive
- Stack name: matches `services/` directory name
- All services attach to `traefik-public` network
- Volume mounts: relative paths, config files `:ro`

**Deploy config:**
```yaml
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
```

### File Naming

- Directories: `kebab-case`
- Scripts: `kebab-case.sh`
- YAML: `kebab-case.yml`
- Environment: `.env` or `.env.example`

### Environment Variables

**Required:** `ACME_EMAIL`, `DOMAIN`, `BASIC_AUTH_USER`, `BASIC_AUTH_HASH`

**In compose files:** `${VARIABLE:-default}` for optional, `${VARIABLE}` for required

### Git Commits

Conventional format: `type(scope): description`

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`

## Important Patterns

1. **Never commit `.env` files** - Use `.env.example` templates
2. **Always `set -e`** in scripts - Exit on first error
3. **Use `|| true`** for idempotent operations
4. **Quote all expansions** - `"${VARIABLE}"`
5. **Check prerequisites** - Validate variables early
6. **Place Traefik on manager nodes** - `node.role == manager`
7. **Use health checks** - Every service needs one

## Common Tasks

**Add a new service:**
1. Create `services/my-service/docker-compose.yml`
2. Add Traefik labels with unique router name
3. Test: `docker compose -f services/my-service/docker-compose.yml config`
4. Commit - GitLab CI validates and deploys

**Add a middleware:**
1. Edit `traefik/dynamic/middlewares.yml`
2. Add under `http.middlewares`
3. Reference: `middleware-name@file` (hot reload, no restart)

**Update Traefik:**
- Static config (`traefik.yml`): requires restart
- Dynamic config (`dynamic/*.yml`): hot reload