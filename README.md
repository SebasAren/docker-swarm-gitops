# Docker Swarm Operations with Traefik

A production-ready Docker Swarm setup using Traefik as reverse proxy with automatic Let's Encrypt SSL certificates. GitOps-ready with GitLab CI/CD.

## Prerequisites

- Docker Swarm initialized
- Domain name pointing to your server(s)
- Ports 80 and 443 accessible from the internet
- GitLab Runner installed on Swarm manager node (for GitOps)

## Quick Start

1. **Copy and configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

2. **Deploy Traefik**
   ```bash
   ./scripts/deploy-traefik.sh
   ```

3. **Deploy example services**
   ```bash
   docker stack deploy -c services/example-web/docker-compose.yml whoami
   docker stack deploy -c services/example-api/docker-compose.yml api
   ```

## Directory Structure

```
├── .gitlab-ci.yml             # GitLab CI/CD pipeline
├── .gitlab/ci/
│   └── templates.yml          # Reusable job templates
├── environments/
│   ├── staging/
│   │   └── .env.example       # Staging environment template
│   └── production/
│       └── .env.example       # Production environment template
├── traefik/
│   ├── traefik.yml            # Static Traefik configuration
│   ├── docker-compose.yml     # Traefik stack definition
│   ├── dynamic/
│   │   └── middlewares.yml    # Security headers, rate limiting
│   └── acme.json              # Let's Encrypt certificates
├── services/
│   ├── example-web/           # Web application template
│   └── example-api/           # API service template
├── scripts/
│   ├── deploy-traefik.sh      # Traefik deployment script
│   ├── deploy.sh              # Generic deployment script
│   └── validate.sh            # Validation script
├── .env.example               # Local environment template
├── .yamllint                  # YAML linting config
└── README.md
```

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ACME_EMAIL` | Email for Let's Encrypt notifications |
| `DOMAIN` | Your primary domain |
| `BASIC_AUTH_USER` | Username for protected routes |
| `BASIC_AUTH_HASH` | htpasswd-generated password hash |

### Adding a New Service

Create a `docker-compose.yml` in `services/your-app/`:

```yaml
version: "3.8"

services:
  app:
    image: your-image:latest
    networks:
      - traefik-public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"
        - "traefik.http.routers.myservice.entrypoints=websecure"
        - "traefik.http.routers.myservice.tls=true"
        - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
        - "traefik.http.services.myservice.loadbalancer.server.port=8080"
        - "traefik.http.routers.myservice.middlewares=security-headers@file"

networks:
  traefik-public:
    external: true
```

Deploy:
```bash
docker stack deploy -c services/your-app/docker-compose.yml myservice
```

### WebSocket Services

Add WebSocket support with these labels:
```yaml
- "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

Traefik handles WebSockets automatically on HTTPS connections.

### UsingMiddlewares

Available middlewares (defined in `traefik/dynamic/middlewares.yml`):

| Middleware | Purpose |
|------------|---------|
| `security-headers@file` | HSTS, XSS protection, content-type nosniff |
| `rate-limit@file` | 100 requests/minute average, 50 burst |
| `compress@file` | Gzip compression |
| `auth@file` | Basic authentication |

Chain multiple middlewares with commas:
```yaml
- "traefik.http.routers.myservice.middlewares=security-headers@file,rate-limit@file"
```

## Traefik Dashboard

Access locally only at `http://127.0.0.1:8080`

To expose publicly (not recommended for production), modify the port mapping in `traefik/docker-compose.yml` and add basic auth.

## Managing Stacks

```bash
# List stacks
docker stack ls

# List services in a stack
docker stack services traefik

# Remove a stack
docker stack rm traefik

# View service logs
docker service logs traefik_traefik
```

## Security Notes

- Dashboard bound to localhost only
- HTTP automatically redirects to HTTPS
- Security headers enabled by default
- ACME certificates stored with restricted permissions (600)

## GitLab CI/CD (GitOps)

This repository is configured for GitOps deployments via GitLab CI/CD.

### Pipeline Stages

| Stage | Trigger | Description |
|-------|---------|-------------|
| validate | All branches/ MRs | YAML lint, shellcheck, compose validation |
| staging | main branch | Auto-deploy to staging |
| production | main branch | Manual approval required |

### GitLab Runner Setup

Install a runner on your Swarm manager node:

```bash
docker run -d --name gitlab-runner --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v gitlab-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest

docker exec -it gitlab-runner gitlab-runner register
```

Configure the runner with `docker` executor and add the `swarm` tag.

### Required GitLab CI/CD Variables

Configure in **Settings > CI/CD > Variables**:

| Variable | Protected | Masked | Description |
|----------|-----------|--------|-------------|
| `ACME_EMAIL` | ✓ | | Let's Encrypt email |
| `DOMAIN_STAGING` | | | Staging domain (e.g., staging.example.com) |
| `DOMAIN_PRODUCTION` | ✓ | | Production domain (e.g., example.com) |
| `BASIC_AUTH_USER` | | | Username for protected routes |
| `BASIC_AUTH_HASH` | | | htpasswd-generated password hash |

### Deployment Flow

```
Push to main → Validate → Deploy Staging → Manual: Deploy Production
```

- **Staging**: Deploys automatically after validation passes
- **Production**: Requires manual approval in GitLab UI

### Manual Deployment

```bash
# Deploy to staging
./scripts/deploy.sh

# Or specify environment
ENVIRONMENT=staging DOMAIN=staging.example.com ./scripts/deploy.sh
ENVIRONMENT=production DOMAIN=example.com ./scripts/deploy.sh
```