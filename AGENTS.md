# Yggdrasil Infrastructure Project

This is the core infrastructure repository for **Yggdrasil**, the main node of the Asgard cluster. It manages a single Debian 12 Docker host running infrastructure services and hobby projects via declarative configuration.

## Core Architecture

**Model**: `Git → Ansible → Docker Engine → Compose Services`

- **Git** is the source of truth for host and service configuration
- **Ansible** handles host bootstrap, hardening, and service deployment
- **Docker Engine + Compose** runs containerized services
- **Caddy** provides shared reverse proxy and TLS termination on the public IP
- **Diun** monitors Docker images for updates and sends notifications via Ntfy
- **Ntfy** provides self-hosted notification endpoints for infrastructure alerts
- **SOPS + age** encrypts service secrets in git; decrypted at deployment time

## Key Principles

1. **Declarative Infrastructure**: Host and service configurations are version-controlled and reproducible
2. **Single Source of Truth**: Git contains all configuration; no manual host changes
3. **Stateless Host**: The host can be rebuilt from configuration; runtime data is managed by services
4. **Prebuilt Services**: Hobby projects arrive as Docker images; this repo owns only their runtime configuration
5. **Idempotent Deployments**: Ansible playbooks can be run multiple times safely
6. **Security by Default**: SSH hardening, firewall rules, and encrypted secrets

## Project Structure

```
asgard-agents/
├── bootstrap/ansible/          # Host bootstrap and service deployment
│   ├── playbooks/              # Ansible playbooks (bootstrap, deploy-services)
│   ├── roles/                  # Reusable Ansible roles (common, docker_host, docker_service, etc)
│   ├── inventory/              # Host inventory and group variables
│   └── requirements.yml        # Ansible collection dependencies
├── services/                   # Deployable services (each in its own directory)
│   ├── reverse-proxy/          # Caddy reverse proxy (shared ingress)
│   ├── ntfy/                   # Notification service
│   ├── diun/                   # Image update monitor
│   ├── uptime-kuma/            # Uptime monitoring
│   └── service-template/       # Template for new services
├── docs/                       # Operational and architectural documentation
│   ├── architecture.md         # System design and layers
│   ├── conventions.md          # Naming, structure, and labeling conventions
│   ├── service-lifecycle.md    # Service workflow from creation to deletion
│   ├── operations-guide.md     # Day-to-day operational tasks
│   ├── onboarding.md           # Operator onboarding guide
│   └── runbooks/               # Step-by-step operational procedures
├── .sops.yaml                  # SOPS age encryption configuration
├── Makefile                    # Primary operator entrypoint (make bootstrap, make ansible-deploy-services, etc)
└── README.md                   # Quick reference for repo scope and common commands
```

## Target Host

- **Hostname**: `yggdrasil`
- **OS**: Debian 12
- **Runtime**: Docker Engine with Compose plugin
- **Network**: Single public IP with Caddy handling all ingress

## Service Structure

Each service lives in `services/<name>/` with this layout:

```
services/<name>/
  compose.yaml                 # Docker Compose definition
  .env.example                 # Environment template (commit to git)
  .env                         # Actual env vars (create from .env.example)
  secrets/                     # Encrypted secrets (SOPS + age)
  README.md                    # Service-specific documentation
```

**Key Conventions**:
- All services must have `.env.example`; a matching `.env` is required before deployment
- Services should run prebuilt Docker images, not build from source
- Monitored services include label `diun.enable=true` for update notifications
- Services are automatically discovered from `services/*/compose.yaml`
- Only the reverse-proxy can bind to public ports; others route through Caddy

## Deployment Order

When bootstrapping Yggdrasil from scratch:

1. `make bootstrap` — Install uv, Ansible, and dependencies locally
2. `make ansible-bootstrap` — Bootstrap the host (common packages, SSH hardening, firewall, Docker)
3. `make ansible-deploy-service SERVICE=reverse-proxy` — Deploy Caddy (must be first)
4. `make ansible-deploy-service SERVICE=ntfy` — Deploy notification service
5. `make ansible-deploy-service SERVICE=diun` — Deploy image update monitor
6. `make ansible-deploy-services` — Deploy all remaining services

## Common Operations

### Deploy a specific service
```bash
make ansible-deploy-service SERVICE=<name>
```

### Deploy all services at once
```bash
make ansible-deploy-services
```

### Validate Ansible before deployment
```bash
make validate              # Syntax check
make validate-all          # Syntax + ansible-lint
```

### View current inventory
```bash
make ansible-inventory
```

## Secrets Management

Service secrets are encrypted with SOPS + age encryption:

1. Age recipient is defined in `.sops.yaml`
2. Encrypted secrets live in `services/<name>/secrets/`
3. During Ansible deployment, secrets are decrypted in memory and passed to containers
4. Only commit encrypted files to git; never commit plaintext secrets

To encrypt/decrypt manually, ensure your age key is in `~/.config/sops/age/keys.txt` and use SOPS directly (see `docs/conventions.md`).

## Documentation Guide

For agent-driven discovery, start with these entry points:

- **First-time operators**: Read `docs/operations-guide.md` for orientation
- **Adding a new service**: Read `docs/service-lifecycle.md` then ask for the `add-service` skill
- **Deploying a service**: Use the `deploy-service` skill or follow `docs/runbooks/add-new-service.md`
- **Understanding architecture**: Read `docs/architecture.md` for deep technical context
- **Managing secrets**: Consult `docs/conventions.md` for SOPS/age workflows
- **Image updates**: Read `docs/runbooks/image-update-workflow.md` or use `update-image` skill

## Ansible Roles

The bootstrap process applies roles in sequence:

- `common` — Package updates, baseline packages (curl, wget, git, etc)
- `ssh_hardening` — SSH security hardening (disable root, disable passwords, etc)
- `firewall` — UFW firewall configuration
- `docker_host` — Docker Engine and Compose plugin installation

The service deployment process uses:

- `docker_service` — Per-service logic: file sync, SOPS decryption, validation, docker-compose convergence

See `bootstrap/ansible/roles/README.md` for detailed role documentation.

## Key Make Targets

| Target | Purpose |
|--------|---------|
| `make bootstrap` | Install local Ansible environment and collections |
| `make validate` | Run syntax checks on playbooks |
| `make ansible-bootstrap` | Bootstrap yggdrasil with base configuration |
| `make ansible-deploy-services` | Deploy all services in dependency order |
| `make ansible-deploy-service SERVICE=<name>` | Deploy a single service |
| `make ansible-inventory` | Print current inventory |

## Integration with OpenCode

This project is configured for OpenCode agent-driven discovery:

- **Skills** in `.opencode/skills/` provide reusable workflows for common tasks (add-service, deploy-service, bootstrap-host, manage-secrets)
- **Documentation** in `docs/` and `docs/runbooks/` provides high-level context and step-by-step guides
- **Conventions** in `docs/conventions.md` document naming, structure, and operational rules

Ask OpenCode questions like:
- "Add a new service for <project>"
- "Deploy the reverse-proxy service"
- "What's the service lifecycle?"
- "Show me how to manage secrets"
- "Bootstrap a fresh host"

OpenCode will automatically discover and use available skills for common workflows.

## Troubleshooting

### Service deployment fails
1. Validate Ansible: `make validate-all`
2. Check service `.env` exists and matches `.env.example`
3. Check secrets are encrypted correctly: `sops services/<name>/secrets/*.yaml`
4. Review Ansible logs for the docker_service role

### SSH access issues
- Ensure your public key is in `bootstrap/ansible/inventory/asgard/group_vars/all.yml` under `authorized_keys`
- SSH hardening disables password auth; key-based auth is required

### Caddy TLS issues
- Cloudflare certificates must be placed in `services/reverse-proxy/secrets/`
- Caddy auto-renews ACME certificates; manual renewal is not needed for Let's Encrypt

## References

- **Ansible Collections**: `community.docker`, `community.general`, `ansible.posix`
- **Tools**: `uv` (Python env manager), `sops` (secret encryption), `age` (encryption key)
- **Documentation**: See `docs/` for architecture, operations, and runbooks

---

**Last Updated**: 2026-05-13  
**For More**: See `docs/operations-guide.md` or run `opencode` in this directory for agent-driven exploration.
