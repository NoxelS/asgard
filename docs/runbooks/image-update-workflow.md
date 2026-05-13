# Image Update Workflow

This runbook describes how Yggdrasil detects Docker image updates and the process for safely updating services.

**For automated help**: Use the `manage-secrets` skill for secrets rotation or `deploy-service` skill for deployment.

**Estimated time**: 10-30 minutes (depending on update complexity)

## Overview

Yggdrasil uses **Diun** (Docker Image Update Notifier) to detect new versions of Docker images and notify you via **Ntfy** (notification service).

```
Diun (on schedule)
  ↓ (queries registries)
  ↓
Detects new image version
  ↓
Posts notification to Ntfy
  ↓
You review notification
  ↓
(Decision) Update or skip
  ↓
If update: Modify compose.yaml, redeploy
```

## Part 1: Understanding the Workflow

### How Diun Works

**Diun runs periodically** (default: every 6 hours):

1. Queries Docker registries (Docker Hub, private registries, etc.)
2. Checks for new versions of watched images
3. Compares available version with currently running version
4. If new version available: sends notification to Ntfy

**Services watched**:
- Must have label `diun.enable=true` in compose.yaml
- Examples: ntfy, diun itself, uptime-kuma, hobby projects

**Services not watched**:
- reverse-proxy (manually updated)
- Infrastructure services without the label

### How Notifications Work

Diun sends notifications to Ntfy with:
- Service name
- Current image tag (e.g., v1.0.0)
- New available image tag (e.g., v1.1.0)
- Registry URL

Ntfy can deliver via:
- Web UI (https://ntfy.yourdomain.com)
- Email
- Webhooks
- MQTT
- Mobile app

## Part 2: Receiving an Update Notification

### Check Ntfy for Updates

```bash
# Access Ntfy web UI
https://ntfy.yourdomain.com

# Or subscribe to email notifications (if configured)

# Or check ntfy logs
ssh yggdrasil docker logs ntfy | grep -i update
```

### Example Notification

```
Service: my-hobby-project
New version available: v2.0.0
Current version: v1.5.0
Registry: docker.io

Release notes: https://github.com/project/releases/tag/v2.0.0
```

## Part 3: Decide Whether to Update

Before updating, consider:

### Check Release Notes

```bash
# Example: Check nginx updates
# 1. Visit Docker Hub or upstream repo
# 2. Read release notes for the version
# 3. Look for:
#    - Breaking changes
#    - Security fixes
#    - Bug fixes
#    - New features
```

### Assess Risk

| Factor | Action |
|--------|--------|
| **Security fix** | Update soon (within days) |
| **Bug fix** | Update at your discretion |
| **New feature** | Update if you need it |
| **Major version change** | Test first if critical |
| **No release notes** | Skip or investigate |

### Test if Critical

For infrastructure services (reverse-proxy, ntfy, diun):

```bash
# Pull and inspect the image
docker pull myregistry.com/myapp:v2.0.0
docker run -it myregistry.com/myapp:v2.0.0 /bin/sh

# Or run locally with docker-compose
cd services/<name>
# Temporarily edit compose.yaml with new version
docker-compose up
# Test locally
docker-compose down
# Revert compose.yaml
```

### Make Decision

- **Update now**: Modify compose.yaml and redeploy
- **Update later**: Note the version, revisit in a few days
- **Skip**: Usually only for major version jumps with breaking changes

## Part 4: Update the Image

### Step 1: Update compose.yaml

```bash
# Navigate to repo root
cd asgard-agents

# Find the service
ls services/*/compose.yaml | xargs grep -l "my-hobby-project"
# Output: services/my-hobby-project/compose.yaml

# Edit the file
vim services/my-hobby-project/compose.yaml
```

**Find and update the image line**:

```yaml
# Before
image: docker.io/myapp:v1.5.0

# After
image: docker.io/myapp:v2.0.0
```

**Save the file** (`:wq` in vim)

### Step 2: Validate the Change

```bash
# Check compose.yaml syntax
docker-compose -f services/my-hobby-project/compose.yaml config

# Should output valid YAML with no errors
```

### Step 3: Verify Only Image Changed

```bash
# See what changed
git diff services/my-hobby-project/compose.yaml
```

**Expected output**:
```
- image: docker.io/myapp:v1.5.0
+ image: docker.io/myapp:v2.0.0
```

Should be only the version change, nothing else.

### Step 4: Commit the Change

```bash
# Stage changes
git add services/my-hobby-project/compose.yaml

# Commit with clear message
git commit -m "chore(services): update my-hobby-project image to v2.0.0"

# Verify
git log --oneline | head -1
```

## Part 5: Deploy the Update

### Option 1: Via Make Target

```bash
# Redeploy service with new image
make ansible-deploy-service SERVICE=my-hobby-project

# Watch the rollout
ssh yggdrasil docker logs -f my-hobby-project
```

### Option 2: Via OpenCode

```
"Deploy the my-hobby-project service"
# OpenCode validates and deploys
```

### What Happens During Deployment

1. Ansible connects to yggdrasil via SSH
2. Syncs updated compose.yaml
3. Runs `docker-compose up -d`
4. Docker pulls new image from registry
5. Stops old container
6. Starts new container
7. Health checks verify it's running

## Part 6: Verify the Update

### Check Service Status

```bash
# Is service running?
ssh yggdrasil docker ps | grep my-hobby-project

# Should show the service with new image tag
# my-hobby-project   docker.io/myapp:v2.0.0
```

### Check Service Logs

```bash
# View recent logs for errors
ssh yggdrasil docker logs -f my-hobby-project

# Look for startup messages
# Should not see errors or crashes
```

### Test Functionality

```bash
# If public service, test via URL
curl https://myproject.example.com/

# If internal, test from yggdrasil
ssh yggdrasil curl http://my-hobby-project:8080/

# Check health status
ssh yggdrasil docker inspect my-hobby-project | grep -A 5 'Health'
# Should show "healthy"
```

### Check Resource Usage

```bash
# Verify resources are normal
ssh yggdrasil docker stats my-hobby-project

# Compare with before update
# CPU, memory should be similar (not spiking)
```

## Part 7: Rollback if Needed

If the update causes issues:

### Immediate Rollback

```bash
# Find the previous commit
git log --oneline services/my-hobby-project/compose.yaml | head -3
# a1b2c3d chore: update my-hobby-project to v2.0.0
# d4e5f6a feat: add my-hobby-project
# ...

# Revert to previous version
git revert a1b2c3d

# Redeploy (will use old image)
make ansible-deploy-service SERVICE=my-hobby-project

# Verify it's running
ssh yggdrasil docker ps | grep my-hobby-project
```

### Investigate the Issue

```bash
# Check logs from failed version
ssh yggdrasil docker logs --tail 100 my-hobby-project

# Look for error messages
# Common issues:
#   - Missing configuration
#   - Incompatible image architecture
#   - Runtime dependency missing
#   - Security changes requiring reauth

# Check upstream for known issues
# Example: Search GitHub issues for the version
```

### Report or Escalate

If it's a bug in the upstream project:

1. Check if issue already reported
2. Report with details: OS, Docker version, config, error logs
3. Consider reverting to previous stable version
4. Wait for upstream fix

## Monitoring Continued Updates

### Check Diun Status

```bash
# View Diun logs to ensure it's still monitoring
ssh yggdrasil docker logs diun

# Should see periodic checks
# "Checking registry... found new version X"
```

### Schedule Regular Reviews

- **Weekly**: Review Ntfy notifications
- **Monthly**: Update non-critical images
- **Quarterly**: Security audit, update all critical images

## Automation Possibilities (Future)

Currently updates are manual. Future improvements could include:

- **Automated patch updates**: Auto-update patch versions (1.0.0 → 1.0.1)
- **Scheduled updates**: Deploy updates on weekends
- **Staged rollout**: Blue-green deployment
- **Automated rollback**: Revert if health checks fail

For now, manual review ensures you have control over your infrastructure.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Image pull fails" | Check registry credentials, network access |
| "Service crashes on startup" | Check config compatibility with new version |
| "High resource usage" | Check if new version has memory leak |
| "Diun not detecting updates" | Verify `diun.enable=true` label present |
| "No notifications" | Check Ntfy is running, notification configured |

## Rollback Checklist

If you need to rollback:

- [ ] Identify working version
- [ ] Review logs for error messages
- [ ] Run `git revert <commit-hash>`
- [ ] Redeploy with `make ansible-deploy-service SERVICE=<name>`
- [ ] Verify service is running
- [ ] Investigate root cause
- [ ] Report issue if it's upstream bug

---

**References**:
- **Diun project**: https://github.com/crazy-max/diun
- **Ntfy project**: https://ntfy.sh
- **Docker Hub**: https://hub.docker.com

**Related docs**: `docs/operations-guide.md`, `docs/service-lifecycle.md`
