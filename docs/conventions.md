# Conventions

This document outlines the naming, structure, and operational conventions used throughout the Yggdrasil infrastructure project.

## Naming Conventions

### Hosts and Infrastructure

- **Naming theme**: Norse/mythological where it adds character
- **Host name**: `yggdrasil` (the world tree, central infrastructure node)
- **Repository**: `asgard-agents` (Asgard cluster infrastructure)

### Services

- **Service directories**: Lowercase alphanumeric with hyphens (`-`), no underscores
  - ✓ `reverse-proxy`, `uptime-kuma`, `my-hobby-project`
  - ✗ `reverse_proxy`, `UptimeKuma`, `MyHobbyProject`

- **Container names** (in compose.yaml): Match directory name or use product name
  - ✓ `caddy`, `ntfy`, `my-service`
  - ✗ Uppercase, underscores, or whitespace

- **Docker images**: Use product/registry naming
  - ✓ `nginx:1.24`, `caddy:latest`, `myregistry.com/myapp:v1.0`
  - ✗ Never use `latest` tag for infrastructure services (pin versions)

- **Docker volumes**: Service name + data suffix
  - ✓ `ntfy-data`, `my-service-data`
  - ✗ `data`, `ntfy_data`, `NTFY-DATA`

- **Docker networks**:
  - `edge` (the shared ingress network)
  - `apps` (shared internal application network)
  - Public services connect to both `edge` and `apps` when they need Caddy routing and backend reachability
  - Internal services connect to `apps` only

### Environment Variables

- **Format**: UPPERCASE_WITH_UNDERSCORES
- **Scope**: Service-specific or generic
  - ✓ `DOMAIN`, `SMTP_HOST`, `LOG_LEVEL`, `API_KEY`
  - ✗ `domain`, `smtp-host`, `log level`, `apiKey`

- **Documentation**: All variables listed in `.env.example` with comments

### Docker Labels

- **Format**: Lowercase dotted notation
- **Monitoring label**: `diun.enable=true` (service image updates should be monitored)
  - Add to any service where you want Diun to detect new image versions
  - Recommended for all services except reverse-proxy (it's special-cased)

Example:
```yaml
labels:
  - diun.enable=true
  - project.monitoring=enabled
  - maintainer=operator@example.com
```

## Directory Structure

### Root Level

```
asgard-agents/
├── .opencode/              # OpenCode configuration
│   ├── skills/            # Reusable skill definitions
│   └── README.md
├── bootstrap/             # Ansible bootstrap and deployment
│   └── ansible/
├── services/              # Deployable services
├── docs/                  # Operational documentation
├── .sops.yaml            # SOPS encryption configuration
├── .gitignore
├── Makefile              # Operator entrypoint
├── README.md             # Project overview
├── AGENTS.md             # OpenCode project rules
└── TODO.md               # Project roadmap
```

### Service Directories

Every service under `services/<name>/` must have:

```
services/<name>/
├── compose.yaml          # Docker Compose definition (REQUIRED)
├── .env.example          # Environment template (REQUIRED)
├── .env                  # Actual config (REQUIRED, never commit plaintext)
├── README.md             # Service documentation (REQUIRED)
└── secrets/              # Encrypted SOPS files (optional)
    ├── README.md
    ├── credentials.yaml  # Encrypted with SOPS
    └── api-keys.yaml     # Encrypted with SOPS
```

**Gitignore rules**:
- `.env` — Never commit plaintext environment
- `secrets/*.yaml` (unencrypted) — Never commit plaintext secrets
- `docker-compose.override.yaml` — Local overrides
- Volumes and runtime data

**What to commit**:
- `.env.example` — Template for configuration
- `secrets/*.yaml` (encrypted) — SOPS-encrypted secrets are safe
- `compose.yaml` — Service definition
- `README.md` — Service documentation

### Documentation

```
docs/
├── architecture.md           # System design and layers
├── conventions.md            # This file
├── service-lifecycle.md      # Service workflow
├── operations-guide.md       # Day-to-day tasks
├── onboarding.md            # Operator onboarding
└── runbooks/
    ├── add-new-service.md   # Step-by-step: add service
    └── image-update-workflow.md  # Update procedures
```

### Bootstrap/Ansible

```
bootstrap/ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Ansible collection dependencies
├── pyproject.toml          # Python dependencies (uv)
├── inventory/
│   └── asgard/
│       ├── hosts.yml       # Host inventory
│       └── group_vars/
│           └── all.yml     # Global variables
├── playbooks/
│   ├── bootstrap.yml       # Host bootstrap
│   ├── deploy-services.yml # Service deployment
│   └── site.yml           # Combined playbook
└── roles/                  # Ansible roles
    ├── common/            # Common tasks
    ├── ssh_hardening/     # SSH security
    ├── firewall/          # UFW firewall
    ├── docker_host/       # Docker setup
    └── docker_service/    # Service deployment
```

## Configuration Patterns

### Docker Compose (compose.yaml)

**Standard service template**:

```yaml
version: '3.8'

services:
  my-service:
    image: myregistry.com/myapp:v1.0.0          # Always pin version
    container_name: my-service                   # Match directory name
    restart: unless-stopped                      # Always auto-restart
    
    networks:
      - edge                                     # Must be on edge network
    
    ports:
      - "8080"                                   # Unpublished port
    
    environment:
      - DOMAIN=${DOMAIN}
      - LOG_LEVEL=${LOG_LEVEL}
    
    env_file:
      - secrets/credentials.yaml                 # For encrypted vars
    
    volumes:
      - my-service-data:/data                    # Persistent storage
    
    labels:
      - diun.enable=true                         # Watch for updates
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  my-database:
    image: postgres:15-alpine
    container_name: my-database
    restart: unless-stopped
    networks:
      - edge
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - my-db-data:/var/lib/postgresql/data
    labels:
      - diun.enable=true

networks:
  edge:
    external: true                               # Shared with Caddy

volumes:
  my-service-data:
    driver: local
  my-db-data:
    driver: local
```

**Key patterns**:
- Use `external: true` for the `edge` network (created once by reverse-proxy)
- Always specify version (supports docker-compose v2)
- Pin container image tags (never use `latest` for infrastructure)
- Use `restart: unless-stopped` for reliability
- Include health checks where applicable
- Use `diun.enable=true` label for monitored services

### Environment Files (.env.example)

**Standard structure**:

```ini
# Service Name Configuration
# ====================================================

# Required: Domain where this service is accessible
DOMAIN=myservice.example.com

# Optional: Logging level (debug, info, warn, error)
LOG_LEVEL=info

# Optional: Email notifications
SMTP_HOST=smtp.example.com
SMTP_PORT=587

# Optional: Performance tuning
MAX_CONNECTIONS=100
CACHE_SIZE=1024
```

**Conventions**:
- Group related variables with comments
- Mark required vs. optional with `# Required` and `# Optional`
- Provide example values
- Document what each variable does
- Keep `.env` and `.env.example` in sync (same variables)

### Secrets Files (SOPS)

**Standard structure**:

```yaml
# services/my-service/secrets/credentials.yaml (encrypted with SOPS)
API_KEY: "your-secret-key"
DB_PASSWORD: "your-db-password"
SMTP_PASSWORD: "your-smtp-password"
```

**Conventions**:
- One encrypted file per secret category
- Use clear names: `credentials.yaml`, `api-keys.yaml`, `certificates.yaml`
- Never commit unencrypted secrets
- Reference in compose.yaml with `env_file:`
- Rotate secrets when credentials are compromised

### Service README.md

**Standard sections**:

```markdown
# Service Name

## Overview
[What the service does and why it's needed]

## Configuration

### Required Environment Variables
- `VARIABLE_NAME` — Description

### Optional Environment Variables
- `VARIABLE_NAME` — Description (default: value)

## Secrets

If secrets are needed:
- `credentials.yaml` — API credentials

## Access

How to access the service:
- URL: https://domain.example.com
- Internal: http://my-service:8080

## Monitoring

- Image updates: Yes (diun.enable=true)
- Health checks: Yes

## Upstream Documentation

Link to original project documentation

## Notes

Any special operational requirements or gotchas
```

## Git Workflows

### Commit Messages

Use conventional commits format:

```
type(scope): brief description

Longer explanation if needed.

Closes #123
```

**Types**:
- `feat` — New feature or service
- `fix` — Bug fix
- `docs` — Documentation only
- `chore` — Maintenance, cleanup
- `ci` — CI/CD changes
- `infra` — Infrastructure changes

**Examples**:
```
feat(services): add ntfy notification service
fix(reverse-proxy): update Caddy to v2.7
docs: enhance service lifecycle documentation
chore: clean up unused volumes on yggdrasil
```

### Branch Strategy

- `main` — Production deployments (always tested)
- Feature branches — For development before PR merge

### PR/Merge Checklist

Before merging to main:
- [ ] Ansible validates successfully (`make validate-all`)
- [ ] Service structure follows conventions
- [ ] `.env.example` and `.env` match
- [ ] Secrets are encrypted (SOPS)
- [ ] No plaintext secrets in git
- [ ] Documentation is updated
- [ ] Tested locally (if applicable)

## Deployment Conventions

### Deployment Order

Strict order (dependencies):
1. `reverse-proxy` — Must be first (provides ingress)
2. `ntfy` — Infrastructure service
3. `diun` — Infrastructure service
4. All other services (any order)

```bash
# Deploy in order
make ansible-deploy-service SERVICE=reverse-proxy
make ansible-deploy-service SERVICE=ntfy
make ansible-deploy-service SERVICE=diun
make ansible-deploy-services  # Everything else
```

### Version Pinning

**Infrastructure services**: Always pin exact version
```yaml
image: caddy:2.7.6          # Good: specific version
image: caddy:latest         # Bad: unpredictable
image: caddy:2.7            # Acceptable: minor version
```

**Hobby projects**: Discuss with maintainer, but prefer pinned

### Idempotency

All Ansible playbooks must be idempotent:
- Running twice = same result as running once
- No "create if not exists" logic needed
- Configuration converges, never diverges

## Operational Conventions

### SSH Access

- **Key-based auth only** — No password authentication
- **Keys in inventory** — `bootstrap/ansible/inventory/asgard/group_vars/all.yml`
- **Disable root login** — Use sudo for privilege escalation
- **SSH hardening applied** — Via `ssh_hardening` role

### Service Logging

- **Docker logs**: `docker logs -f <service-name>`
- **No persistent logging** — Logs are container-local (consider centralized logging for multi-host)
- **Tail for debugging**: `docker logs --tail 100 <service-name>`

### Backup Responsibility

- **Infrastructure services** (ntfy, diun, caddy) — Essential, minimal data
- **Application services** — Each service responsible for own backup strategy
- **Volumes** — Back up regularly, especially databases

### Monitoring

- **Diun** — Detects image updates for labeled services
- **Health checks** — Built into compose.yaml
- **Manual monitoring** — `docker ps`, `docker logs`, `docker stats`
- **Future**: Centralized logging, alerting

## Tooling Conventions

### Python/Ansible

- **Package manager**: `uv` (Python environment manager)
- **Ansible version**: 2.14+ (from `pyproject.toml`)
- **Collections**: See `requirements.yml`

### Secret Management

- **Encryption tool**: SOPS (mozilla/sops)
- **Key management**: age (FiloSottile/age)
- **Key location**: `~/.config/sops/age/keys.txt` (never commit)
- **Git-safe secrets**: Always encrypted before commit

### Docker

- **Engine version**: Latest stable (Debian 12 repos)
- **Compose version**: v2+ (Compose plugin)
- **Image format**: OCI-compliant
- **Registry auth**: Via docker config.json

## Checklist for New Services

When adding a new service, ensure:

- [ ] Directory name is lowercase with hyphens
- [ ] `compose.yaml` exists and is valid
- [ ] `.env.example` exists and documents all variables
- [ ] `.env` is created from `.env.example`
- [ ] Services use the appropriate shared network (`edge` for public ingress, `apps` for internal service traffic)
- [ ] No services bind to 80/443 (except reverse-proxy)
- [ ] Image tag is pinned (not `latest`)
- [ ] `diun.enable=true` label present (if updates should be monitored)
- [ ] Health checks included (if applicable)
- [ ] Secrets encrypted with SOPS (if needed)
- [ ] `README.md` documents the service
- [ ] `.gitignore` prevents plaintext commits
- [ ] Ansible playbook passes validation

---

**References**: See `docs/service-lifecycle.md` for the complete service onboarding workflow.
