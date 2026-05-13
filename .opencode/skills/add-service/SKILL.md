---
name: add-service
description: Onboard a new Docker service to Yggdrasil with complete setup and validation
license: MIT
metadata:
  audience: operators
  workflow: service-lifecycle
---

## What I do

I guide you through adding a new Docker service to Yggdrasil, from initial setup through validation and deployment readiness:

- Create service directory structure under `services/<name>/`
- Generate `compose.yaml` from the service template
- Create environment file templates (`.env.example` and `.env`)
- Set up secrets directory if encryption is needed
- Validate the service against project conventions
- Optionally deploy the service to yggdrasil

## When to use me

Use this when you are onboarding a new Docker service to Yggdrasil, whether it's:
- An existing hobby project with a prebuilt Docker image
- A new infrastructure service
- A third-party application you want to run

## How I work

1. **Gather requirements**: Ask about the service name, Docker image, port bindings, and whether it needs secrets
2. **Validate naming**: Ensure the service name follows conventions (lowercase, hyphens, no underscores)
3. **Create structure**: Set up the directory and files from the service template
4. **Environment setup**: Create `.env.example` with documented variables and `.env` with defaults
5. **Secrets setup**: Create encrypted secret files if needed (SOPS + age)
6. **Validation**: Check the service against project conventions:
   - `.env.example` exists and matches `.env`
   - No direct port bindings (except reverse-proxy)
   - Includes `diun.enable=true` label if image updates should be monitored
   - compose.yaml is valid YAML and follows Yggdrasil patterns
7. **Deployment**: Optionally deploy the service with `make ansible-deploy-service SERVICE=<name>`

## Key decisions I'll help with

- **Service naming**: Should it be `my-service` or `myservice`? (Answer: lowercase with hyphens)
- **Networking**: How should the service be exposed? (Answer: through Caddy reverse proxy, not direct port binding)
- **Monitoring**: Should image updates trigger notifications? (Answer: Yes, add `diun.enable=true` label)
- **Secrets**: Does the service need encrypted credentials? (Answer: Use SOPS under `services/<name>/secrets/`)

## References

- Service template: `services/service-template/` — baseline structure and compose patterns
- Conventions: `docs/conventions.md` — naming rules, labels, and structure requirements
- Service lifecycle: `docs/service-lifecycle.md` — complete workflow documentation
- Runbook: `docs/runbooks/add-new-service.md` — step-by-step guide
- Docker Compose: `services/*/compose.yaml` — examples from existing services

## Common workflows

**Add a simple stateless service**
```
Ask me to add a service for example.com using nginx:latest
I'll create the directory, compose file, and validate it's ready for deployment.
```

**Add a service with secrets**
```
Ask me to add a service that needs API keys or database passwords
I'll create the secrets directory and help you encrypt credentials with SOPS
```

**Add a service with persistent data**
```
Ask me to add a service that needs volumes or databases
I'll create the compose file with proper volume mounts and backup documentation
```

## Troubleshooting

**Service fails validation**
- Check that `.env.example` and `.env` match in structure
- Ensure compose.yaml is valid YAML
- Verify the service is not binding ports directly (use Caddy routes instead)

**Secrets not encrypting**
- Confirm age key exists at `~/.config/sops/age/keys.txt`
- Check that `.sops.yaml` in repo root has the correct recipient
- Run `sops services/<name>/secrets/*.yaml` to verify encryption

**Deployment fails**
- Run `make validate-all` to check Ansible syntax
- Review the `docker_service` role output in the Ansible logs
- Check that all required environment variables are set in `.env`

---

**Tip**: After adding the service, document any service-specific setup, monitoring requirements, or operational quirks in `services/<name>/README.md`.
