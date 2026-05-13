# Bootstrap and Ansible

This directory contains all infrastructure-as-code for Yggdrasil using Ansible.

## Overview

**Goal**: Automate host bootstrap and service deployment via Ansible playbooks

**Model**: Git → Ansible → Docker Engine → Compose Services

**Tools**:
- **Ansible 2.14+** — Infrastructure automation
- **uv** — Python environment and dependency management
- **Docker Compose** — Service runtime configuration

## Directory Structure

```
bootstrap/ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Ansible collection dependencies
├── pyproject.toml          # Python dependencies (managed by uv)
├── uv.lock                 # Locked dependency versions
├── inventory/
│   └── asgard/
│       ├── hosts.yml       # Host inventory definition
│       └── group_vars/
│           └── all.yml     # Global variables for all hosts
├── playbooks/
│   ├── bootstrap.yml       # One-time host setup
│   ├── deploy-services.yml # Service deployment (idempotent)
│   └── site.yml           # Combined playbook
└── roles/
    ├── common/            # Base packages and updates
    ├── ssh_hardening/     # SSH security hardening
    ├── firewall/          # UFW firewall configuration
    ├── docker_host/       # Docker Engine and Compose installation
    └── docker_service/    # Service deployment logic
```

## Playbooks

### bootstrap.yml

**Purpose**: One-time initialization of a fresh Debian 12 host

**What it does**:
1. Applies `common` role — Package updates, baseline tools
2. Applies `ssh_hardening` role — Hardens SSH configuration
3. Applies `firewall` role — UFW firewall with 22, 80, 443 allowed
4. Applies `docker_host` role — Docker Engine and Compose plugin

**When to run**:
```bash
make ansible-bootstrap
```

**Who can run**: Must have sudo access on target host (will prompt for sudo password)

**Idempotent**: Yes — Can run multiple times safely

**Output**:
- Updated system packages
- SSH hardened (keys only, no password, no root)
- UFW firewall active (minimal rules)
- Docker Engine installed and running
- Docker Compose plugin v2+ available

### deploy-services.yml

**Purpose**: Deploy services from `services/*/compose.yaml` to yggdrasil

**What it does**:
1. Auto-discovers services from `services/*/` directories
2. Applies `docker_service` role to each service
3. For each service:
   - Syncs compose.yaml, .env, and secrets to host
   - Decrypts SOPS-encrypted secrets in-place
   - Validates compose.yaml syntax
   - Runs `docker-compose up -d`
   - Verifies container started successfully

**When to run**:
```bash
# Deploy all services
make ansible-deploy-services

# Deploy single service
make ansible-deploy-service SERVICE=reverse-proxy

# Deploy multiple specific services
make ansible-deploy-services SERVICES=reverse-proxy,ntfy,diun
```

**Idempotent**: Yes — Can run multiple times (only restarts if config changed)

**Deployment order**:
- Services are deployed in discovery order (alphabetical by directory name)
- Special handling for `reverse-proxy` (always first)
- Other services can be deployed in any order

**Selective deployment**:
```bash
# Deploy only ntfy
make ansible-deploy-service SERVICE=ntfy

# Deploy all services except reverse-proxy
make ansible-deploy-services SERVICES='!reverse-proxy'
```

### site.yml

**Purpose**: Combined bootstrap + service deployment (for fresh hosts)

**Usage**:
```bash
# Bootstrap and deploy all services in one go
make ansible-bootstrap  # First time only
make ansible-deploy-services  # Services after
```

## Roles

### common

**Purpose**: Base system configuration and package management

**Tasks**:
- Update package lists
- Install baseline tools (curl, wget, git, vim, htop, etc)
- Install Python 3 (required for Ansible)
- Install uv for Python environment management

**Files**:
```
roles/common/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
└── templates/
```

**Idempotent**: Yes

**Dependencies**: None

### ssh_hardening

**Purpose**: Secure SSH configuration

**Tasks**:
- Disable root login
- Disable password authentication (key-based only)
- Disable X11 forwarding
- Set strong ciphers and key exchange algorithms
- Configure `~/.ssh/authorized_keys` from inventory

**Files**:
```
roles/ssh_hardening/
├── defaults/main.yml       # SSH config defaults
├── tasks/main.yml
├── handlers/main.yml
├── templates/sshd_config.j2
└── README.md
```

**Key configuration**:
- Public keys loaded from inventory: `authorized_keys` list
- Add your SSH public key to `bootstrap/ansible/inventory/asgard/group_vars/all.yml`
- SSH key format: `ssh-rsa AAAA...` or `ssh-ed25519 AAAA...`

**Idempotent**: Yes

**Dependencies**: common

### firewall

**Purpose**: UFW (Uncomplicated Firewall) configuration

**Tasks**:
- Enable UFW
- Set default deny policy (drop incoming)
- Allow SSH (port 22) for management
- Allow HTTP (port 80) for web traffic
- Allow HTTPS (port 443) for encrypted traffic

**Files**:
```
roles/firewall/
├── defaults/main.yml
├── tasks/main.yml
└── handlers/main.yml
```

**Ports**:
- 22 (SSH) — Infrastructure management
- 80 (HTTP) — Caddy web traffic
- 443 (HTTPS) — Caddy encrypted traffic
- All others: Blocked

**Idempotent**: Yes

**Dependencies**: common

### docker_host

**Purpose**: Docker Engine and Compose plugin installation

**Tasks**:
- Add Docker repository (from official Docker source)
- Install Docker Engine (latest stable)
- Install Docker Compose plugin v2+
- Start and enable Docker daemon
- Create `edge` Docker network for services

**Files**:
```
roles/docker_host/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
└── README.md
```

**Output**:
```bash
docker version        # Should show Engine and Docker Compose
docker network ls     # Should include 'edge' network
docker ps            # Should show running containers
```

**Idempotent**: Yes

**Dependencies**: common

### docker_service

**Purpose**: Deploy individual Docker services from compose.yaml

**Tasks**:
1. **Validation** — Check service structure (compose.yaml, .env, secrets)
2. **Sync** — Copy service files to host (`/opt/services/<name>/`)
3. **Decrypt secrets** — SOPS decrypts encrypted files in-place
4. **Convergence** — Run `docker-compose up -d`
5. **Verification** — Check container started and is healthy

**Files**:
```
roles/docker_service/
├── defaults/main.yml
├── tasks/
│   ├── main.yml
│   ├── validate.yml
│   ├── sync.yml
│   ├── secrets.yml
│   └── compose.yml
├── handlers/main.yml
├── templates/
│   └── ...
└── README.md
```

**Key variables**:
- `docker_service_name` — Service directory name
- `docker_service_path` — Path on host (`/opt/services/<name>`)
- `docker_service_selector` — Filter which services to deploy

**Validation checks**:
- compose.yaml exists and is valid YAML
- .env exists and matches .env.example in structure
- Secrets directory (if present) contains encrypted files only
- Service is not trying to bind ports 80/443 (only reverse-proxy can)
- No plaintext secrets in git or on host

**Idempotent**: Yes — Only restarts container if config changed

**Dependencies**: docker_host

## Variables

### Inventory Variables

Location: `bootstrap/ansible/inventory/asgard/group_vars/all.yml`

**Example**:
```yaml
---
# SSH hardening: public keys to authorize
authorized_keys:
  - "ssh-ed25519 AAAA... user@machine"
  - "ssh-rsa AAAA... user@machine"

# Host configuration
ansible_host: 1.2.3.4         # Public IP of yggdrasil
ansible_user: ubuntu          # SSH user
ansible_port: 22              # SSH port

# Docker configuration
docker_version: "latest"       # Docker Engine version
docker_compose_version: "latest"  # Compose plugin version

# Firewall
ufw_rules:
  - rule: allow
    port: 22
    proto: tcp

# Service deployment
services_path: /opt/services   # Where services are deployed on host
```

### Role Variables

Each role has defaults in `roles/<name>/defaults/main.yml`. Override in inventory if needed.

## Security

### SSH

- **Authentication**: Key-based only (passwords disabled)
- **Root login**: Disabled
- **Authorization**: Keys from inventory
- **Port**: 22 (configurable, default in inventory)

**Add your SSH key**:
```yaml
# bootstrap/ansible/inventory/asgard/group_vars/all.yml
authorized_keys:
  - "ssh-ed25519 AAAA..." # Your public key
```

### Firewall

- **Default policy**: Drop all incoming traffic
- **Allowed**: SSH, HTTP, HTTPS
- **Protected**: All other ports
- **Outbound**: Allowed (can pull images, reach registries)

### Secrets

- **Storage**: Encrypted at rest in git (SOPS + age)
- **Decryption**: Only during deployment (in-memory)
- **No logging**: Plaintext secrets never in logs or artifacts
- **Key management**: Age key in `~/.config/sops/age/keys.txt` (never commit)

## Workflow

### Bootstrap a Fresh Host

```bash
# 1. Add SSH public key to inventory
vim bootstrap/ansible/inventory/asgard/group_vars/all.yml
# Add your public key to authorized_keys list

# 2. Update host IP in inventory
vim bootstrap/ansible/inventory/asgard/hosts.yml
# Set ansible_host to actual IP

# 3. Install local dependencies
make bootstrap

# 4. Bootstrap the host
make ansible-bootstrap
# Will prompt for sudo password

# 5. Deploy services
make ansible-deploy-services

# 6. Verify
make ansible-inventory
ssh yggdrasil docker ps
```

### Deploy/Update Services

```bash
# Make changes in services/<name>/
vim services/<name>/compose.yaml

# Commit
git add services/<name>/
git commit -m "Update service config"

# Deploy
make ansible-deploy-service SERVICE=<name>

# Verify
ssh yggdrasil docker logs -f <name>
```

### Rerun Bootstrap

```bash
# Safe to run multiple times
make ansible-bootstrap

# Only changes things if config differs
```

## Troubleshooting

### SSH Access Fails

```bash
# Verify key is in inventory
cat bootstrap/ansible/inventory/asgard/group_vars/all.yml | grep ssh_

# Verify SSH access manually
ssh -i ~/.ssh/id_rsa ubuntu@<IP>

# Update key in inventory and redeploy
make ansible-bootstrap
```

### Service Deployment Fails

```bash
# Check Ansible syntax
make validate-all

# Check service structure
ls services/<name>/{compose.yaml,.env.example,.env}

# Check secrets encryption
file services/<name>/secrets/*.yaml

# Run with verbose output
cd bootstrap/ansible && $(UV) run ansible-playbook -i inventory/asgard/hosts.yml playbooks/deploy-services.yml -vvv
```

### Docker Won't Start

```bash
# Check host resources
ssh yggdrasil free -m
ssh yggdrasil df -h

# Check Docker status
ssh yggdrasil sudo systemctl status docker

# View Docker logs
ssh yggdrasil sudo journalctl -u docker -n 50
```

## Common Commands

```bash
# View inventory structure
make ansible-inventory

# Syntax check (before deployment)
make validate

# Full validation (syntax + lint)
make validate-all

# Run bootstrap on host
make ansible-bootstrap

# Deploy specific service
make ansible-deploy-service SERVICE=ntfy

# Deploy all services
make ansible-deploy-services

# Raw Ansible playbook execution
cd bootstrap/ansible && $(UV) run ansible-playbook -i inventory/asgard/hosts.yml playbooks/bootstrap.yml
```

## References

- **Ansible**: https://docs.ansible.com/
- **Docker**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **uv**: https://astral.sh/uv/

## Next Steps

- **Add a service**: See `docs/runbooks/add-new-service.md`
- **Deploy services**: See `docs/operations-guide.md`
- **Manage secrets**: See `docs/conventions.md`
- **Full documentation**: See `docs/architecture.md`

---

**Last Updated**: 2026-05-13
