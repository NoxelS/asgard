# Operations Guide

This guide covers day-to-day operational tasks for managing Yggdrasil and its services.

## Quick Reference

### Essential Commands

```bash
# View service status
make ansible-inventory

# Deploy a service
make ansible-deploy-service SERVICE=<name>

# Deploy all services
make ansible-deploy-services

# Validate Ansible before deployment
make validate-all

# Check Yggdrasil status
ssh yggdrasil docker ps
ssh yggdrasil docker logs -f <service-name>
```

### OpenCode Skills

```bash
# In your OpenCode terminal:
# Add a new service
"Add a new service for <project>"

# Deploy a service with validation
"Deploy the <service-name> service"

# Bootstrap from scratch
"Bootstrap a fresh yggdrasil server"

# Manage secrets
"Add an API key secret to <service-name>"
```

## Day-to-Day Tasks

### Check Service Status

```bash
# List running services on yggdrasil
ssh yggdrasil docker ps

# Check specific service
ssh yggdrasil docker ps | grep <service-name>

# Detailed service info
ssh yggdrasil docker inspect <service-name>
```

### View Service Logs

```bash
# Follow logs in real-time
ssh yggdrasil docker logs -f <service-name>

# Show last 100 lines
ssh yggdrasil docker logs --tail 100 <service-name>

# Grep for errors
ssh yggdrasil docker logs <service-name> | grep -i error
```

### Monitor Resource Usage

```bash
# Real-time stats for all containers
ssh yggdrasil docker stats

# Stats for specific service
ssh yggdrasil docker stats <service-name>

# Check disk space
ssh yggdrasil df -h

# Check memory usage
ssh yggdrasil free -m
```

### Restart a Service

Normally, service restarts happen via redeployment:

```bash
# Redeploy a service (standard method)
make ansible-deploy-service SERVICE=<name>
```

For emergency restart only:

```bash
# Manual restart (not recommended; loses git tracking)
ssh yggdrasil docker-compose -f /opt/services/<name>/compose.yaml restart
```

### Access Service Container

```bash
# Execute command in running container
ssh yggdrasil docker exec -it <service-name> /bin/sh

# Examples:
ssh yggdrasil docker exec -it ntfy sh              # ntfy shell
ssh yggdrasil docker exec -it my-db psql -U user  # PostgreSQL client
```

### View Network Connectivity

```bash
# List Docker networks
ssh yggdrasil docker network ls

# Inspect edge network (service mesh)
ssh yggdrasil docker network inspect edge

# Check service IP on edge network
ssh yggdrasil docker inspect <service-name> -f '{{json .NetworkSettings.Networks}}'
```

### Check Reverse Proxy Routing

```bash
# View Caddy logs (reverse proxy)
ssh yggdrasil docker logs -f reverse-proxy

# Caddy status page (usually on port 2019)
curl http://yggdrasil:2019/config/apps/http/servers/default

# Check which domains are routed
ssh yggdrasil docker exec reverse-proxy caddy list-modules
```

## Image Updates Workflow

### Receive Update Notifications

Updates are detected by Diun and sent to Ntfy:

1. **Diun runs on schedule** (default: every 6 hours)
2. **Checks image registries** for new versions
3. **Sends notification to Ntfy** if update available
4. **You review the notification** on the Ntfy UI or via email/webhook

### Decide Whether to Update

Before updating:

- Check upstream **release notes** for breaking changes
- Test locally if it's a critical service
- Schedule update if it requires downtime

### Perform the Update

1. **Update compose.yaml**:
   ```bash
   # Edit the image tag
   vim services/<name>/compose.yaml
   
   # Change: image: myregistry.com/myapp:v1.0
   # To:     image: myregistry.com/myapp:v1.1
   ```

2. **Commit change**:
   ```bash
   git add services/<name>/compose.yaml
   git commit -m "Update my-app image to v1.1"
   ```

3. **Deploy**:
   ```bash
   make ansible-deploy-service SERVICE=<name>
   ```

4. **Monitor the rollout**:
   ```bash
   ssh yggdrasil docker logs -f <name>  # Watch startup logs
   ```

5. **Verify success**:
   ```bash
   ssh yggdrasil docker ps | grep <name>   # Should be running
   curl https://my-domain/                 # Should be accessible
   ```

### Rollback if Needed

If an update breaks a service:

1. **Identify the version** that was working
2. **Revert compose.yaml**:
   ```bash
   git log --oneline services/<name>/compose.yaml | head -5  # Find commit
   git revert <commit-hash>
   # or
   git checkout <commit-hash> -- services/<name>/compose.yaml
   ```

3. **Redeploy**:
   ```bash
   make ansible-deploy-service SERVICE=<name>
   ```

4. **Investigate the issue**:
   - Check upstream for known issues
   - Review image release notes
   - File issue with image maintainer if needed

## Secrets Management

### Add a New Secret

```bash
# Create encrypted secret file
cat > services/<name>/secrets/my-secret.yaml <<EOF
API_KEY: "your-secret-value"
DB_PASSWORD: "your-password"
EOF

# Encrypt with SOPS
sops -e services/<name>/secrets/my-secret.yaml

# Verify encryption (should be unreadable)
cat services/<name>/secrets/my-secret.yaml | head -c 100

# Reference in compose.yaml
env_file:
  - secrets/my-secret.yaml
```

### Rotate a Secret

If a secret is compromised:

```bash
# Decrypt (read-only)
sops services/<name>/secrets/my-secret.yaml

# Edit encrypted file directly
sops services/<name>/secrets/my-secret.yaml
# Edit the value and save; SOPS will re-encrypt automatically

# Redeploy service with new secret
make ansible-deploy-service SERVICE=<name>

# Revoke old secret on the provider side (e.g., rotate API key)
```

### Backup Your Age Key

Your age encryption key is critical and cannot be recovered if lost:

```bash
# Back it up securely (not in git, not in cloud storage)
cp ~/.config/sops/age/keys.txt ~/secure-backup/

# Verify it works
export SOPS_AGE_KEY_FILE=~/secure-backup/keys.txt
sops services/ntfy/secrets/*.yaml  # Should decrypt successfully
```

## Backup and Recovery

### Check What Needs Backup

Services with persistent data:

```bash
ssh yggdrasil docker volume ls
ssh yggdrasil docker volume inspect <volume-name>
```

### Backup Service Data

```bash
# For services with volumes, back up the volume data
ssh yggdrasil docker run --rm -v <volume-name>:/data -v /tmp:/backup \
  alpine tar czf /backup/<volume-name>-$(date +%Y%m%d).tar.gz -C /data .

# Copy backup locally
scp yggdrasil:/tmp/<volume-name>-*.tar.gz ~/backups/
```

### Restore Service Data

```bash
# Create new volume
ssh yggdrasil docker volume create <volume-name>

# Restore from backup
scp ~/backups/<volume-name>-*.tar.gz yggdrasil:/tmp/
ssh yggdrasil docker run --rm -v <volume-name>:/data -v /tmp:/backup \
  alpine tar xzf /backup/<volume-name>-*.tar.gz -C /data
```

## Host Maintenance

### System Updates

```bash
# SSH to host and update packages
ssh yggdrasil sudo apt-get update && sudo apt-get upgrade -y

# Restart services after major updates (optional)
make ansible-deploy-services
```

### Disk Cleanup

```bash
# Remove unused images
ssh yggdrasil docker image prune -a

# Remove unused volumes
ssh yggdrasil docker volume prune

# Remove unused networks
ssh yggdrasil docker network prune

# Check disk usage
ssh yggdrasil du -sh /var/lib/docker
```

### SSH Access Troubleshooting

If you lose SSH access:

1. **Verify key is in inventory**:
   ```bash
   cat bootstrap/ansible/inventory/asgard/group_vars/all.yml | grep public_key
   ```

2. **Add your key** (if missing):
   ```bash
   # Edit inventory
   vim bootstrap/ansible/inventory/asgard/group_vars/all.yml
   
   # Add your public key to authorized_keys list
   ```

3. **Redeploy SSH configuration**:
   ```bash
   # This applies the ssh_hardening role
   make ansible-bootstrap
   ```

## Deployment Order and Dependencies

### Fresh Bootstrap

1. **Local setup**: `make bootstrap`
2. **Host setup**: `make ansible-bootstrap`
3. **Reverse proxy**: `make ansible-deploy-service SERVICE=reverse-proxy`
4. **Infrastructure**: `make ansible-deploy-service SERVICE=ntfy && make ansible-deploy-service SERVICE=diun`
5. **Applications**: `make ansible-deploy-services`

### Partial Redeployment

Only reverse-proxy and infrastructure services have strict ordering. Application services can be deployed individually:

```bash
# Safe to deploy individual services in any order
make ansible-deploy-service SERVICE=my-app-1
make ansible-deploy-service SERVICE=my-app-2
```

### Full Redeployment

```bash
# Redeploys all services in correct order
make ansible-deploy-services
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs for error
ssh yggdrasil docker logs <service-name>

# Verify compose.yaml syntax
docker-compose -f services/<name>/compose.yaml config

# Check environment variables
cat services/<name>/.env

# Verify secrets are encrypted
file services/<name>/secrets/*

# Check DNS resolution
ssh yggdrasil nslookup <registry-domain>
```

### Port Already in Use

```bash
# Find service using port
ssh yggdrasil netstat -tlnp | grep :8080

# List port mappings
ssh yggdrasil docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### High Disk Usage

```bash
# Find what's using disk space
ssh yggdrasil du -sh /var/lib/docker/*

# Most likely: service volumes or images
ssh yggdrasil du -sh /var/lib/docker/volumes/*/
```

### Container Crashes

```bash
# Check exit code
ssh yggdrasil docker inspect <service-name> | grep -A5 'ExitCode'
# 0 = clean exit, other = error

# View crash logs
ssh yggdrasil docker logs <service-name> | tail -50

# Check resource limits
ssh yggdrasil docker inspect <service-name> | grep -A5 'Memory'
```

## Validation Commands

Run these regularly to ensure everything is healthy:

```bash
# Check Ansible syntax
make validate-all

# Check Ansible connectivity
make ansible-inventory

# Check service status
ssh yggdrasil docker ps --all

# Check network connectivity
ssh yggdrasil docker network ls

# Check disk and memory
ssh yggdrasil df -h
ssh yggdrasil free -m

# Check recent logs for errors
ssh yggdrasil docker logs -f --tail 50 reverse-proxy
```

## Emergency Procedures

### Complete Host Failure

```bash
# 1. Rebuild from backup infrastructure
make ansible-bootstrap

# 2. Restore volumes from backups
# See "Restore Service Data" above

# 3. Redeploy all services
make ansible-deploy-services

# 4. Verify restoration
ssh yggdrasil docker ps
```

### Compromised Service

```bash
# 1. Stop the service
make ansible-deploy-service SERVICE=<name>  # This will restart it cleanly

# 2. Investigate in logs
ssh yggdrasil docker logs <name>

# 3. Update secrets if compromised
# Use manage-secrets skill to rotate credentials

# 4. Verify security
# Review firewall rules, network access
```

## Reference

- **Documentation**: `docs/` directory
- **Runbooks**: `docs/runbooks/` for step-by-step procedures
- **Skills**: Use `add-service`, `deploy-service`, `bootstrap-host`, `manage-secrets`
- **Infrastructure**: `bootstrap/ansible/` for Ansible configuration
- **Services**: `services/` for service configurations

---

**Questions?** Check `docs/service-lifecycle.md` for broader context, or ask OpenCode for help with specific tasks using available skills.
