---
name: bootstrap-host
description: Bootstrap yggdrasil from scratch with Debian 12, Docker, and Ansible
license: MIT
metadata:
  audience: operators
  workflow: host-setup
---

## What I do

I guide you through the complete bootstrap process for a fresh yggdrasil host, from initial Debian 12 setup through running Docker services:

- Verify prerequisites (SSH access, sudo capability, Python 3)
- Run `make bootstrap` to set up your local Ansible environment
- Run `make ansible-bootstrap` to configure yggdrasil (hardening, firewall, Docker)
- Deploy core infrastructure services in the correct order (reverse-proxy → ntfy → diun)
- Validate the bootstrap was successful
- Provide post-bootstrap operational guidance

## When to use me

Use this when you:
- Have a fresh Debian 12 host that will become yggdrasil
- Are recovering from a host failure and rebuilding from scratch
- Need to understand the bootstrap sequence for documentation or training
- Want a guided walkthrough instead of running Make targets directly

## How I work

### Phase 1: Local Setup
1. **Verify tools**: Check that `uv` is installed (or install it)
2. **Run local bootstrap**: Execute `make bootstrap` to install Ansible and dependencies

### Phase 2: Host Bootstrap
1. **SSH verification**: Confirm SSH access to yggdrasil with sudo capability
2. **Run bootstrap playbook**: Execute `make ansible-bootstrap` (will prompt for sudo password)
3. **Verify results**: Check that Docker Engine and Compose plugin installed successfully
4. **Inventory check**: Display current inventory with `make ansible-inventory`

### Phase 3: Service Deployment
1. **Deploy reverse-proxy**: `make ansible-deploy-service SERVICE=reverse-proxy` (requires TLS certs)
2. **Deploy ntfy**: `make ansible-deploy-service SERVICE=ntfy` (notification infrastructure)
3. **Deploy diun**: `make ansible-deploy-service SERVICE=diun` (image update monitor)
4. **Deploy remaining services**: `make ansible-deploy-services` (or individually as needed)

### Phase 4: Validation
1. **SSH hardening**: Verify key-based auth works, password auth disabled
2. **Docker status**: Check `docker ps` on yggdrasil shows running containers
3. **Network connectivity**: Verify Caddy is listening on public IP
4. **Monitoring**: Confirm ntfy and diun are operational

## Prerequisites before starting

- Fresh Debian 12 host with root or sudo access
- SSH key-based access configured
- Public IP assigned to the host
- Your local machine has `uv` installed (or I'll help install it)
- Admin access to domain DNS (if using Let's Encrypt with Caddy)

## Key decisions I'll help with

**SSH Configuration**
- Should use key-based authentication only
- Your public key goes in `bootstrap/ansible/inventory/asgard/group_vars/all.yml`
- SSH hardening disables root login and password auth

**TLS Certificates**
- For Let's Encrypt: Caddy auto-renews, no manual intervention needed
- For Cloudflare: Place origin cert in `services/reverse-proxy/secrets/`
- For other providers: Consult Caddy documentation and configure in the Caddyfile

**Firewall**
- Bootstrap installs UFW firewall
- SSH (port 22), HTTP (80), and HTTPS (443) are allowed
- All other ports are blocked by default

**Host Identity**
- Hostname must be `yggdrasil` (set in inventory)
- Single IP address (public)
- No multi-node clustering at this stage

## References

- **Inventory**: `bootstrap/ansible/inventory/asgard/` — host configuration
- **Bootstrap playbook**: `bootstrap/ansible/playbooks/bootstrap.yml`
- **Roles applied**: common → ssh_hardening → firewall → docker_host
- **System requirements**: Debian 12, sudo capability, ~2GB disk minimum
- **Network requirements**: Public IP, DNS A record pointing to host

## Common workflows

**New production host**
```
Ask me to bootstrap a fresh yggdrasil server
I'll guide you through the complete setup with best practices
```

**Recovery scenario**
```
My yggdrasil host is broken, help me rebuild it
I'll walk you through restoring from configuration
```

**Dry run / learning**
```
Show me what bootstrap does without actually running it
I'll explain each step and what it configures
```

## Troubleshooting

**"Cannot connect to host via SSH"**
- Verify SSH key is in `bootstrap/ansible/inventory/asgard/group_vars/all.yml`
- Check host IP/hostname in inventory is correct
- Ensure SSH key has correct permissions (600)

**"Sudo password prompt"**
- `make ansible-bootstrap` requires sudo for host configuration
- Be ready to enter the sudo password when prompted
- Use a user account with sudoers access

**"Docker installation failed"**
- Check that Debian 12 is installed and up-to-date
- Review Ansible logs for specific error
- Verify disk space is available for Docker images

**"Caddy fails to start"**
- TLS certificates must be in place (Let's Encrypt or manual cert)
- Check `services/reverse-proxy/secrets/` for certificate files
- Review Caddy logs: `docker logs reverse-proxy`

**"Services won't start"**
- Ensure `.env` files are created from `.env.example`
- Check that secrets are encrypted with SOPS
- Verify environment variables are not missing or malformed

---

**After bootstrap completes**: Review `docs/operations-guide.md` for day-to-day operations and monitoring procedures.
