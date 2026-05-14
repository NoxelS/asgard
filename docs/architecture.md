# Architecture

## Model

**The declarative infrastructure pipeline**:

```
Git (source of truth)
  ↓
Ansible (convergence engine)
  ↓
Docker Engine (runtime)
  ↓
Compose Services (containerized workloads)
```

**The service ingress model**:

```
Public IP (yggdrasil host)
  ↓
Caddy (reverse proxy, TLS termination, routing)
  ↓
Docker Edge Network (internal service mesh)
  ↓
Individual services (no direct public binding)
```

**The internal application network model**:

```
Docker Apps Network (shared backend network)
  ↓
Internal services and service-to-service APIs
```

**The monitoring and updates model**:

```
Docker Images (on public registries)
  ↓
Diun (image update detection)
  ↓
Ntfy (notification delivery)
  ↓
Operator (manual pull and redeploy)
```

## Core Principles

1. **Git is the source of truth** — All configuration is version-controlled and reproducible
2. **Declarative not imperative** — Describe desired state; Ansible converges automatically
3. **Idempotent deployments** — Playbooks can run multiple times safely
4. **Stateless host** — Rebuild the host from git without data loss (except volumes)
5. **Stateful services** — Application data lives in volumes, not in the host
6. **Prebuilt images** — Services run prebuilt Docker images; this repo owns configuration only
7. **Security by default** — Hardened host, encrypted secrets, key-based auth, minimal ports
8. **Single admin** — Designed for solo operator; no multi-user or RBAC complexity

## Current Scope

- **Single host**: `yggdrasil`
- **OS**: Debian 12 (stable, long-term support)
- **Runtime**: Docker Engine with Compose plugin v2+
- **Network**: Public IP with Caddy reverse proxy
- **Storage**: Local volumes (no network storage)
- **Monitoring**: Self-hosted (ntfy + diun)
- **Secrets**: SOPS + age encryption (in-git encryption)
- **Backup**: Per-service responsibility (not automated yet)

## Architectural Layers

### 1. Host Layer

**Responsibility**: Base Debian system, hardening, and Docker runtime

**Components**:
- Debian 12 with security updates
- SSH key-based authentication (password auth disabled)
- UFW firewall (22, 80, 443 allowed; all else denied)
- Docker Engine with Compose plugin
- Python 3 for Ansible

**Configuration**: `bootstrap/ansible/roles/{common,ssh_hardening,firewall,docker_host}`

**Deployment**: `make ansible-bootstrap` (one-time)

**Validation**:
```bash
ssh yggdrasil docker version        # Docker installed
ssh yggdrasil docker ps             # Services visible
ssh yggdrasil docker network ls     # Edge network exists
```

### 2. Ingress Layer

**Responsibility**: Public-facing routing, TLS termination, service discovery

**Components**:
- Caddy reverse proxy (single public entrypoint)
- Docker `edge` network (internal service mesh)
- DNS A record (points domain to public IP)
- TLS certificates (Let's Encrypt or manual)

**Configuration**: `services/reverse-proxy/`

**Deployment**: `make ansible-deploy-service SERVICE=reverse-proxy` (first service)

**Key constraints**:
- Only reverse-proxy binds to ports 80 and 443
- All other services bind to unpublished ports
- Caddy routes by domain or path to each service
- Services communicate via Docker DNS or network IP

**Example routing**:
```
ntfy.example.com → Caddy → 10.0.9.2:5000 (ntfy container)
myapp.example.com → Caddy → 10.0.9.3:8080 (app container)
```

### 3. Infrastructure Services Layer

**Responsibility**: Monitoring, notifications, and lifecycle management

**Components**:
- **Ntfy** (notification service) — HTTP endpoint for pushing alerts
- **Diun** (image update detection) — Watches container images, sends alerts to ntfy
- Auto-discovery system — Finds new services automatically

**Configuration**: `services/{ntfy,diun}`

**Deployment order**:
1. reverse-proxy (must be first; provides ingress)
2. ntfy (infrastructure service)
3. diun (infrastructure service)

**Operational workflows**:
- Diun detects new image versions
- Sends notification to Ntfy
- Operator reviews and decides to update
- Operator changes image tag in compose.yaml
- Operator runs `make ansible-deploy-service SERVICE=<name>`

### 4. Application Services Layer

**Responsibility**: User-facing and hobby applications

**Components**:
- Prebuilt Docker images (external sources)
- Docker Compose definitions (this repo or remote repos)
- Environment configuration (`.env` files)
- Persistent volumes (app-managed)

**Configuration**: `services/*` plus `remote-services/*` for repo-managed stacks

**Deployment**: `make ansible-deploy-service SERVICE=<name>` or `make ansible-deploy-services`

**Service discovery**: Automatic from `services/*/compose.yaml` and `remote-services/*/repo.yaml`

**Update workflow**: Diun → Ntfy → Manual decision → Image tag change → Redeploy

## Data Flow

### Deployment Flow

```
1. Developer commits changes to git
   (e.g., new service, image tag update, env vars)
   ↓
2. Operator runs `make ansible-deploy-service SERVICE=<name>`
   ↓
3. Ansible connects to yggdrasil via SSH
   ↓
4. Ansible copies files (compose.yaml, .env)
   ↓
5. Ansible decrypts secrets (SOPS + age key)
   ↓
6. Ansible runs `docker-compose up -d`
   ↓
7. Docker pulls image (if new), starts container(s)
   ↓
8. Service connects to edge network
   ↓
9. Caddy detects service, routes traffic
```

### Update Notification Flow

```
1. Diun wakes up (scheduled interval)
   ↓
2. Queries Docker Hub/registry for each watched image
   ↓
3. Compares available version with running version
   ↓
4. If new version available:
   - Creates alert message
   - POSTs to Ntfy
   ↓
5. Ntfy receives and stores notification
   ↓
6. Operator checks Ntfy (manual review)
   ↓
7. Operator updates image tag in services/<name>/compose.yaml
   ↓
8. Operator runs `make ansible-deploy-service SERVICE=<name>`
   ↓
9. Deployment flow (see above)
```

## Naming Conventions

- **Infrastructure host**: Norse/mythological theme (e.g., `yggdrasil`)
- **Services**: Product names for clarity (e.g., `ntfy`, `diun`, `caddy`)
- **Directories**: Lowercase with hyphens (e.g., `reverse-proxy`, `uptime-kuma`)
- **Environment variables**: UPPERCASE_WITH_UNDERSCORES
- **Docker labels**: Lowercase dotted notation (e.g., `diun.enable=true`)

## Security Model

**SSH Access**:
- Key-based authentication only
- Password auth disabled
- Root login disabled
- Specific user accounts with sudo access

**Secrets**:
- Encrypted at rest in git (SOPS + age)
- Decrypted only during deployment
- Never logged or exposed in plaintext
- Stored in `services/<name>/secrets/`

**Network**:
- UFW firewall: only ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
- Internal Docker network (`edge`) for service communication
- Shared `apps` network for internal service-to-service communication
- Public services can join both `edge` and `apps`

**Configuration**:
- Git audit trail for all infrastructure changes
- No manual edits on the host (configuration is immutable)
- Rollback by reverting git commit and redeploying

## Scaling Considerations

**Current design** supports:
- Single host (Debian 12, ~10-30 services)
- Typical hobby project workloads
- Single operator

**Future expansion** could support:
- Multiple hosts with load balancer
- Persistent volume storage (NFS, ceph)
- Centralized logging and monitoring
- Multi-environment (dev, staging, prod)
- Team-based operations (RBAC, audit logging)
