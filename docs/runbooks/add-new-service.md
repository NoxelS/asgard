# Add a New Service

This is a step-by-step runbook for adding a new Docker service to Yggdrasil.

**For automated help**: Use the `add-service` skill in OpenCode.

**Estimated time**: 15-30 minutes

## Prerequisites

- [ ] You have local clone of asgard-agents repo
- [ ] You've identified the service to add (name, Docker image, configuration)
- [ ] You understand what environment variables and secrets the service needs
- [ ] You have write access to the repository

## Step 1: Plan the Service (5 min)

### Gather Requirements

Ask yourself:

1. **Service name** (lowercase with hyphens)
   - Example: `my-hobby-project`, `web-scraper`, `api-server`
   - No underscores, no uppercase

2. **Docker image** (pinned version)
   - Example: `myregistry.com/myapp:v1.0.0`
   - Never use `latest` for infrastructure

3. **Port** (what port does it listen on?)
   - Example: `8080`, `5000`, `3000`
   - This will be unpublished (Caddy routes to it)

4. **Networking** (public or internal?)
   - Public: Routed through Caddy reverse proxy
   - Internal: Only accessible within Docker network

5. **Configuration** (environment variables)
   - Example: `DOMAIN`, `LOG_LEVEL`, `API_KEY`
   - These go in `.env.example`

6. **Secrets** (encrypted credentials)
   - Example: Database passwords, API tokens
   - These go in `services/<name>/secrets/`

7. **Volumes** (persistent data?)
   - Example: Database data, uploads, config
   - These go in `compose.yaml`

8. **Monitoring** (watch for image updates?)
   - Add `diun.enable=true` label if yes

### Example: Adding ntfy

```
Name: ntfy
Image: ntfy.sh/ntfy:v2.22.0
Port: 5000
Public: Yes (routed through Caddy)
Environment: DOMAIN, SMTP_HOST, SMTP_PORT
Secrets: SMTP_PASSWORD
Volumes: ntfy-data:/var/lib/ntfy
Monitoring: Yes
```

## Step 2: Create Directory Structure (2 min)

```bash
# Navigate to repo root
cd asgard-agents

# Create service directory
mkdir services/<name>

# Verify it was created
ls -la services/<name>
```

Example:
```bash
mkdir services/ntfy
```

## Step 3: Create compose.yaml (5 min)

Copy the service template and customize:

```bash
# Copy template
cp services/service-template/compose.yaml services/<name>/compose.yaml

# Edit the file
vim services/<name>/compose.yaml
```

**Update these fields**:

```yaml
services:
  <name>:                    # Container name
    image: <your-image>      # Docker image with pinned version
    container_name: <name>
    ports:
      - "8080"               # Your service port
    environment:
      - VAR1=${VAR1}
      - VAR2=${VAR2}
    volumes:
      - <name>-data:/data    # If needed
    labels:
      - diun.enable=true     # If monitoring updates

volumes:
  <name>-data:               # If needed
```

**Key points**:
- Always use `networks: - edge` (shared ingress network)
- Pin image versions (no `latest`)
- Use unpublished ports (not `80:80`)
- Include health checks if possible

**Example (ntfy)**:

```yaml
version: '3.8'

services:
  ntfy:
    image: ntfy.sh/ntfy:v2.22.0
    container_name: ntfy
    restart: unless-stopped
    
    networks:
      - edge
    
    ports:
      - "5000"
    
    environment:
      - DOMAIN=${DOMAIN}
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
    
    env_file:
      - secrets/credentials.yaml
    
    volumes:
      - ntfy-data:/var/lib/ntfy
    
    labels:
      - diun.enable=true
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  edge:
    external: true

volumes:
  ntfy-data:
    driver: local
```

Validate syntax:
```bash
docker-compose -f services/<name>/compose.yaml config
# Should output valid YAML, no errors
```

## Step 4: Create Environment Files (5 min)

### Create .env.example

```bash
vim services/<name>/.env.example
```

List all environment variables the service needs:

```ini
# My Service Configuration
# ====================================================

# Required: Domain where service is accessible
DOMAIN=myservice.example.com

# Optional: Logging level
LOG_LEVEL=info

# Optional: External API settings
API_KEY=your-api-key-here
API_URL=https://api.example.com

# Optional: Performance tuning
MAX_CONNECTIONS=100
TIMEOUT_SECONDS=30
```

**Conventions**:
- Group related variables with comments
- Mark `# Required` and `# Optional`
- Provide example values
- Document what each does

### Create .env from .env.example

```bash
# Copy template
cp services/<name>/.env.example services/<name>/.env

# Edit with actual values
vim services/<name>/.env
```

Fill in real values:

```ini
DOMAIN=ntfy.mydomain.com
LOG_LEVEL=info
API_KEY=sk_real_key_value_12345
API_URL=https://api.myservice.com
MAX_CONNECTIONS=50
TIMEOUT_SECONDS=30
```

### Verify .env and .env.example match

They should have the same variables (different values):

```bash
# Check that both files have same structure
diff <(cut -d= -f1 services/<name>/.env.example | sort) \
     <(cut -d= -f1 services/<name>/.env | sort)
# Should show no differences (or only expected ones)
```

## Step 5: Set Up Secrets (if needed) (5 min)

If the service needs encrypted secrets (API keys, passwords):

### Create secrets directory

```bash
mkdir services/<name>/secrets
echo "# Encrypted secrets (SOPS)" > services/<name>/secrets/README.md
```

### Create encrypted secret file

```bash
# Create plaintext file (temporary, will be encrypted)
cat > services/<name>/secrets/credentials.yaml <<EOF
API_KEY: "your-secret-api-key"
DB_PASSWORD: "your-database-password"
SMTP_PASSWORD: "your-smtp-password"
EOF

# Encrypt with SOPS (requires age key)
sops -e services/<name>/secrets/credentials.yaml > services/<name>/secrets/credentials.enc.yaml

# Delete plaintext (important!)
rm services/<name>/secrets/credentials.yaml

# Rename encrypted file
mv services/<name>/secrets/credentials.enc.yaml services/<name>/secrets/credentials.yaml

# Verify it's encrypted (not readable plaintext)
file services/<name>/secrets/credentials.yaml
# Should say: "data"
```

### Reference in compose.yaml

```yaml
env_file:
  - secrets/credentials.yaml
```

**Important**:
- Never commit plaintext secrets
- Always encrypt before committing
- Verify `.gitignore` prevents plaintext commits

## Step 6: Create README.md (3 min)

```bash
vim services/<name>/README.md
```

Include:

```markdown
# Service Name

## Overview

[What this service does and why it's needed]

Example: "ntfy is a self-hosted notification service used for Diun update alerts and infrastructure notifications."

## Configuration

### Environment Variables

- `DOMAIN` — Domain where service is accessible
- `LOG_LEVEL` — Logging verbosity (debug, info, warn, error)

### Secrets

- `credentials.yaml` — API key and password

## Access

- URL: https://[DOMAIN]
- Internal: http://ntfy:5000

## Monitoring

- Image updates: Yes (diun.enable=true)
- Health checks: Yes

## Upstream Documentation

[Link to project repo or docs]

## Notes

Any special operational requirements:
- [Gotcha 1]
- [Gotcha 2]
```

## Step 7: Validate Structure (3 min)

```bash
# Check all required files exist
ls -la services/<name>/{compose.yaml,.env.example,.env,README.md}

# Validate compose.yaml
docker-compose -f services/<name>/compose.yaml config

# Verify .env files match
diff <(cut -d= -f1 services/<name>/.env.example | sort) \
     <(cut -d= -f1 services/<name>/.env | sort)

# Check secrets are encrypted (if present)
[ -d services/<name>/secrets ] && file services/<name>/secrets/*.yaml
```

**Expected output**:
```
services/<name>/compose.yaml       ✓ File exists
services/<name>/.env.example       ✓ File exists
services/<name>/.env               ✓ File exists
services/<name>/README.md          ✓ File exists

(Valid docker-compose output) ✓
(No diff output) ✓
data (encrypted)                ✓
```

## Step 8: Test Locally (optional but recommended)

```bash
# Start service locally to test compose.yaml
cd services/<name>
docker-compose up -d

# Check if it started
docker-compose ps

# View logs
docker-compose logs -f

# Test connectivity
curl http://localhost:8080/

# Stop when done
docker-compose down
cd ../..
```

## Step 9: Commit Changes

```bash
# Check what changed
git status

# Stage changes
git add services/<name>/

# Commit with meaningful message
git commit -m "feat(services): add ntfy notification service"

# Verify commit
git log --oneline | head -1
```

## Step 10: Deploy

### Via Make target

```bash
# Deploy single service
make ansible-deploy-service SERVICE=<name>

# Monitor deployment
ssh yggdrasil docker logs -f <name>

# Verify success
ssh yggdrasil docker ps | grep <name>
```

### Via OpenCode

```
"Deploy the <name> service"
# OpenCode will validate and deploy
```

## Verification Checklist

After deployment:

- [ ] Service is running: `ssh yggdrasil docker ps | grep <name>`
- [ ] No startup errors: `ssh yggdrasil docker logs <name> | grep -i error`
- [ ] Accessible: `curl https://<domain>/` (if public)
- [ ] Health check passing: `ssh yggdrasil docker inspect <name>`
- [ ] On edge network: `ssh yggdrasil docker network inspect edge | grep <name>`
- [ ] Monitoring enabled: `ssh yggdrasil docker inspect <name> | grep diun.enable`

## Common Issues

| Issue | Solution |
|-------|----------|
| "compose.yaml not found" | Check directory exists and file is named correctly |
| ".env file not found" | Copy from `.env.example` and fill in values |
| "Secrets not encrypting" | Verify age key: `ls ~/.config/sops/age/keys.txt` |
| "Service won't start" | Check logs: `docker-compose logs` |
| "Port already in use" | Change port in compose.yaml to unpublished |
| "Can't connect to registry" | Verify image name and auth credentials |

## Rollback

If deployment fails:

```bash
# Revert git changes
git revert <commit-hash>

# Redeploy (removes service)
make ansible-deploy-services

# Investigate the issue
cat services/<name>/compose.yaml
cat services/<name>/.env
docker-compose -f services/<name>/compose.yaml config
```

---

**Next**: See `docs/service-lifecycle.md` for ongoing operations and maintenance.
