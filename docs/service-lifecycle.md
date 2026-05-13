# Service Lifecycle

This document describes the complete lifecycle of a Docker service in Yggdrasil, from conception through decommissioning.

## Phases Overview

1. **Planning** — Decide what service to add and validate compatibility
2. **Onboarding** — Create service directory structure and configuration
3. **Testing** — Validate locally before deployment
4. **Deployment** — Deploy to yggdrasil for the first time
5. **Operations** — Monitor, update, and maintain the service
6. **Decommissioning** — Safely remove the service

## Phase 1: Planning

### Gather Requirements

Before creating a service, determine:

- **Service name**: What will it be called? (lowercase with hyphens, e.g., `my-app`)
- **Docker image**: What prebuilt image will it run? (e.g., `nginx:latest`, `myregistry.com/app:v1.0`)
- **Ports**: What port(s) does the service listen on? (typically 8080 or higher)
- **Networking**: Should it be public-facing or internal-only?
- **Configuration**: What environment variables does it need?
- **Secrets**: Does it need API keys, passwords, or credentials?
- **Volumes**: Does it need persistent storage? (database, config, data)
- **Dependencies**: Does it depend on other services? (database, cache, etc.)
- **Monitoring**: Should image updates trigger notifications? (diun.enable=true)

### Validate Compatibility

- **Prebuilt images only** — No building from source in this repo
- **Public registry or internal registry** — Images must be accessible to yggdrasil
- **Standard Compose patterns** — No Docker Swarm, Kubernetes, or exotic configs
- **No root user** — Service should run as non-root in container
- **Ephemeral or volume-backed** — No state in the container filesystem

### Naming Conventions

**Service directory name**:
- Lowercase alphanumeric
- Hyphens for word separation (no underscores)
- Examples: `reverse-proxy`, `uptime-kuma`, `my-hobby-project`

**Docker container name** (in compose.yaml):
- Same as directory name or product name
- Example: `ntfy`, `caddy`, `kuma`

## Phase 2: Onboarding

### Create Service Structure

Use the `add-service` skill or follow this manual process:

1. **Create directory**:
   ```bash
   mkdir services/<name>
   ```

2. **Create compose.yaml**:
   - Copy from `services/service-template/compose.yaml`
   - Update container name, image, ports, volumes, environment
   - Add `diun.enable=true` label if you want update notifications

3. **Create .env.example**:
   - List all environment variables the service needs
   - Provide example values or placeholders
   - Document what each variable does
   - Include optional variables commented out

4. **Create .env**:
   - Copy from `.env.example`
   - Fill in actual values for your deployment

5. **Create secrets directory** (if needed):
   ```bash
   mkdir services/<name>/secrets
   echo "# Encrypted secrets go here" > services/<name>/secrets/README.md
   ```

6. **Create README.md**:
   - Describe what the service does
   - Link to upstream documentation
   - List any special operational requirements
   - Explain how to access the service (URL, credentials)

### Example: Adding `ntfy`

```
services/ntfy/
├── compose.yaml              # ntfy container, ports, volumes
├── .env.example              # DOMAIN, SMTP settings
├── .env                       # Filled-in values
├── secrets/
│   └── smtp-password.yaml    # Encrypted SMTP credentials
└── README.md                 # How to use ntfy
```

### Compose.yaml Best Practices

```yaml
services:
  my-service:
    image: registry.example.com/myapp:v1.0.0  # Always pin version, never 'latest'
    container_name: my-service                 # Must match service directory name
    restart: unless-stopped                    # Auto-restart on failure
    networks:
      - edge                                   # Always on edge network for routing
    ports:
      - "8080"                                 # Unpublished port (Caddy routes to it)
    environment:
      - API_KEY=${API_KEY}                     # From .env file
    env_file:
      - secrets/credentials.yaml               # From encrypted secrets
    volumes:
      - my-service-data:/data                  # Persistent storage
    labels:
      - diun.enable=true                       # Watch for image updates
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  edge:
    external: true                             # Shared with Caddy

volumes:
  my-service-data:
    driver: local
```

### Environment File (.env.example)

```ini
# ntfy configuration example
# Copy to .env and fill in your values

# Required: Domain where ntfy is accessible
DOMAIN=ntfy.example.com

# Optional: Email notifications via SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Optional: Rate limiting
RATE_LIMIT=100

# Optional: Retention period (days)
RETENTION=7
```

### Secrets File (for encryption)

For secrets, create a YAML file and encrypt it with SOPS:

```bash
# Create plaintext (do NOT commit)
cat > services/my-service/secrets/credentials.yaml <<EOF
API_KEY: "secret-key-value"
DB_PASSWORD: "secret-password"
EOF

# Encrypt with SOPS
sops -e services/my-service/secrets/credentials.yaml > services/my-service/secrets/credentials.enc.yaml
rm services/my-service/secrets/credentials.yaml  # Delete plaintext

# Reference in compose.yaml
env_file:
  - secrets/credentials.enc.yaml
```

## Phase 3: Testing

### Pre-Deployment Validation

Before deploying to yggdrasil:

1. **Structure check**:
   ```bash
   # All required files present?
   ls services/<name>/{compose.yaml,.env.example,.env,README.md}
   ```

2. **Compose syntax**:
   ```bash
   # Valid YAML?
   docker-compose -f services/<name>/compose.yaml config
   ```

3. **Environment consistency**:
   ```bash
   # .env.example and .env match in variable names?
   diff <(grep '=' services/<name>/.env.example) <(grep '=' services/<name>/.env) | wc -l
   # Should be 0 or show only expected differences
   ```

4. **Secrets encryption**:
   ```bash
   # Secrets are encrypted (not readable plaintext)?
   file services/<name>/secrets/*.yaml
   # Should output: data (binary)
   ```

5. **Naming conventions**:
   - Service directory: lowercase with hyphens ✓
   - No underscores in names ✓
   - Container name matches directory ✓

6. **Network setup**:
   - Does compose.yaml use `edge` network? ✓
   - Are ports unpublished (not `80:80` or `443:443`)? ✓
   - No direct port bindings except reverse-proxy? ✓

7. **Monitoring label**:
   - If image should be monitored, is `diun.enable=true` present? ✓

8. **Documentation**:
   - Is README.md complete with usage instructions? ✓
   - Are environment variables documented? ✓

### Use the add-service Skill

The `add-service` skill automates validation:

```bash
# In OpenCode, ask:
"Add a new service for my-app using myregistry.com/myapp:v1.0"
# The skill will validate everything and prepare for deployment
```

## Phase 4: Deployment

### First-Time Deployment

1. **Ensure prerequisites**:
   ```bash
   # Reverse-proxy already deployed?
   make ansible-inventory  # Should show reverse-proxy running
   
   # Local Ansible environment ready?
   make ansible-collections
   ```

2. **Deploy service**:
   ```bash
   make ansible-deploy-service SERVICE=<name>
   ```

3. **Verify deployment**:
   ```bash
   # On yggdrasil:
   ssh yggdrasil docker ps                    # Service should be listed
   ssh yggdrasil docker logs -f <name>        # Check for errors
   ssh yggdrasil docker network inspect edge  # Service should be on edge network
   ```

4. **Test connectivity**:
   ```bash
   # If public service:
   curl https://<domain>/                     # Should respond
   
   # If internal service:
   ssh yggdrasil curl http://<container-ip>:8080/  # Should respond
   ```

### Redeployment (After Changes)

If you update the service configuration:

1. **Make changes locally**:
   ```bash
   # Edit compose.yaml, .env, or secrets
   vim services/<name>/compose.yaml
   vim services/<name>/.env
   ```

2. **Validate changes**:
   ```bash
   docker-compose -f services/<name>/compose.yaml config
   ```

3. **Redeploy**:
   ```bash
   make ansible-deploy-service SERVICE=<name>
   ```

4. **Verify**:
   ```bash
   ssh yggdrasil docker ps | grep <name>
   ```

### Use the deploy-service Skill

```bash
# In OpenCode, ask:
"Deploy the my-app service"
# The skill will validate and deploy automatically
```

## Phase 5: Operations

### Monitoring

**Manual monitoring**:
```bash
# Check service status
ssh yggdrasil docker ps | grep <name>

# View logs
ssh yggdrasil docker logs -f <name>

# Check health
ssh yggdrasil docker inspect <name> | jq '.[] | .State.Health'
```

**Automated monitoring** (Diun + Ntfy):
- Diun watches services with `diun.enable=true` label
- Detects new image versions in registry
- Sends notification to Ntfy
- You review and decide whether to update

### Image Updates

When Diun detects a new image version:

1. **Receive notification** via Ntfy
2. **Review release notes** on the image registry
3. **Test locally** (if critical service):
   ```bash
   docker pull myregistry.com/myapp:v1.1
   docker run -it myregistry.com/myapp:v1.1 /bin/sh
   ```
4. **Update compose.yaml**:
   ```bash
   # Change image: myregistry.com/myapp:v1.0 → v1.1
   vim services/<name>/compose.yaml
   ```
5. **Commit and deploy**:
   ```bash
   git add services/<name>/compose.yaml
   git commit -m "Update my-app image to v1.1"
   make ansible-deploy-service SERVICE=<name>
   ```
6. **Monitor logs**:
   ```bash
   ssh yggdrasil docker logs -f <name>
   ```

### Troubleshooting

**Service won't start**:
- Check logs: `docker logs <name>`
- Verify environment variables: `cat services/<name>/.env`
- Check secrets are encrypted: `file services/<name>/secrets/*`
- Review compose.yaml syntax: `docker-compose config`

**Service runs but not accessible**:
- Verify it's on edge network: `docker network inspect edge`
- Check Caddy routing: `docker logs reverse-proxy`
- Verify port binding: `docker port <name>`
- Check health: `docker inspect <name> | jq '.[] | .State.Health'`

**Resource issues**:
- Monitor resource usage: `docker stats <name>`
- Check disk space: `df -h`
- Adjust resource limits in compose.yaml if needed

### Maintenance

**Regular tasks**:
- Monitor logs for errors
- Check for image updates (Diun notifications)
- Review disk usage (especially volumes)
- Validate backups if service has state

**Periodic updates**:
- Update images to latest stable version
- Review security advisories for dependencies
- Update documentation if requirements change

## Phase 6: Decommissioning

### Before Removing

1. **Back up data** (if applicable):
   ```bash
   ssh yggdrasil docker exec <name> <backup-command>
   # Copy backup locally
   scp yggdrasil:/path/to/backup .
   ```

2. **Notify users** (if applicable)
3. **Update documentation** to note the deprecation

### Remove Service

1. **Stop the service** (optional, git will drive removal):
   ```bash
   ssh yggdrasil docker-compose -f /opt/services/<name>/compose.yaml down
   ```

2. **Delete from git**:
   ```bash
   rm -rf services/<name>
   git add -A
   git commit -m "Remove service: <name>"
   ```

3. **Redeploy** (Ansible will remove it):
   ```bash
   make ansible-deploy-services
   ```

4. **Verify removal**:
   ```bash
   ssh yggdrasil docker ps | grep <name>  # Should be empty
   ```

5. **Clean up volumes** (if needed):
   ```bash
   ssh yggdrasil docker volume rm <name>-data
   ```

## Summary

| Phase | Actions | Skill | Artifacts |
|-------|---------|-------|-----------|
| Plan | Gather requirements, validate compatibility | — | Service spec |
| Onboard | Create structure, write config | `add-service` | services/<name>/ |
| Test | Validate locally before deployment | — | Test results |
| Deploy | Deploy to yggdrasil | `deploy-service` | Running container |
| Operate | Monitor, update, troubleshoot | — | Logs, notifications |
| Remove | Back up, decommission, clean up | — | Git commit |

---

**Reference**: OpenCode skills can automate many of these steps. Use `add-service`, `deploy-service`, and `manage-secrets` for a guided experience.
