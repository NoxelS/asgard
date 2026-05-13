---
name: deploy-service
description: Deploy or redeploy a service to yggdrasil with validation and SOPS decryption
license: MIT
metadata:
  audience: operators
  workflow: service-deployment
---

## What I do

I handle the complete deployment of a service from your working directory to yggdrasil:

- Validate the service structure and configuration
- Check that all required environment variables are present
- Decrypt SOPS-encrypted secrets in-place during deployment
- Run Ansible to sync files and start the service with `docker-compose`
- Monitor the deployment for errors and provide actionable feedback
- Show service status after deployment

## When to use me

Use this when you:
- Deploy a new service for the first time
- Redeploy an existing service after configuration changes
- Update secrets and need to decrypt them for deployment
- Want to deploy a single service without deploying all services at once
- Need validation and error reporting before attempting deployment

## How I work

1. **Validate prerequisites**: Check that `.env` exists and matches `.env.example`, secrets are encrypted, compose.yaml is valid
2. **Prepare deployment**: Ensure Ansible environment is ready with `make ansible-collections`
3. **Run deployment**: Execute `make ansible-deploy-service SERVICE=<name>` with proper error handling
4. **Monitor status**: Check if the service started successfully with `docker-compose ps`
5. **Report results**: Show the deployment status and any issues that arose

## What I validate

- Service directory exists under `services/<name>/`
- `compose.yaml` is present and valid YAML
- `.env` file matches `.env.example` in structure
- Secrets directory (if present) contains encrypted files only
- Service follows Yggdrasil conventions (no direct port bindings for most services)
- Docker image specified in compose.yaml is available

## Deployment safety

This skill:
- **Never** modifies files without your approval
- **Never** runs `docker-compose down` without explicit request
- **Never** replaces encrypted secrets with plaintext
- Always runs validation before attempting deployment
- Provides clear error messages if validation fails

## Common workflows

**Deploy a new service**
```
Ask me to deploy my-service
I'll validate everything and deploy it to yggdrasil
```

**Redeploy after config changes**
```
Ask me to redeploy the reverse-proxy service
I'll pick up your environment changes and apply them
```

**Deploy with secrets**
```
Ask me to deploy a service that has encrypted secrets
I'll decrypt the secrets at deployment time and pass them to the container
```

## References

- Makefile targets: `make ansible-deploy-service SERVICE=<name>`
- Service examples: `services/` — see existing services for patterns
- Docker Compose: https://docs.docker.com/compose/
- Ansible docker_service role: `bootstrap/ansible/roles/docker_service/`

## Troubleshooting

**"Service directory not found"**
- Verify the service name is correct
- Check that `services/<name>/` exists
- Ensure `services/<name>/compose.yaml` is present

**"Missing .env file"**
- Create `.env` from `.env.example`
- Copy the template and fill in your deployment-specific values

**"Secrets not encrypted"**
- Run the `manage-secrets` skill to encrypt unencrypted files
- Check that SOPS is configured in `.sops.yaml`

**"Deployment failed - port already in use"**
- Ensure no other service is binding to that port
- Check that the service is using Caddy for ingress, not direct ports

**"Environment variable mismatch"**
- Compare your `.env` with `.env.example`
- Add any missing variables that are in `.env.example`

---

**Tip**: After deploying, check service logs with `docker logs -f <container-name>` on yggdrasil to verify the service is running correctly.
