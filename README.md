# Asgard

Single-host operations repo for `yggdrasil` and the Docker services it runs.

## Scope

- One main server: `yggdrasil`
- One environment
- Git as source of truth for host and service configuration
- Ansible for host bootstrap and service deployment
- Docker Compose for runtime
- Caddy as the shared reverse proxy
- Ntfy for self-hosted notifications
- Diun for image update notifications
- SOPS + age for encrypted service secrets

## Host Identity

- Host: `yggdrasil`

## Repository Layout

- `docs/`: architecture, onboarding, runbooks
- `bootstrap/ansible/`: host bootstrap and service deployment
- `services/`: side projects, Compose files, and service-local secrets
- `remote-services/`: repo-managed stacks with env/secrets stored here

## Status

This repo is currently focused on bootstrapping one Docker host, running core infrastructure services, and deploying side projects from `services/*`.

## Common Commands

Use the top-level `Makefile` as the primary operator entrypoint.

```bash
make bootstrap
make validate
make ansible-syntax
make ansible-bootstrap
make ansible-deploy-service SERVICE=ntfy
make ansible-deploy-service SERVICE=diun
make ansible-deploy-services
make ansible-deploy-service SERVICE=reverse-proxy
```

## Service Layout

Each deployable service lives in its own directory under `services/<name>/`.

Recommended contents:

```bash
services/<name>/
  compose.yaml
  .env
  Dockerfile
  .env.example
  secrets/
  README.md
```

Files under `services/<name>/secrets/` are intended to stay encrypted in git and are decrypted by Ansible during deployment.
Non-secret Compose variables should live in a tracked `.env` created from `.env.example`.
Services should normally run prebuilt Docker images and opt into update notifications with `diun.enable=true`.

## Deploy Order

1. Bootstrap `yggdrasil` with `make ansible-bootstrap`
2. Add the Cloudflare origin certificate and private key under `services/reverse-proxy/secrets/` and deploy the shared reverse proxy with `make ansible-deploy-service SERVICE=reverse-proxy`
3. Deploy `ntfy` with `make ansible-deploy-service SERVICE=ntfy`
4. Deploy `diun` with `make ansible-deploy-service SERVICE=diun`
5. Deploy individual side projects with `make ansible-deploy-service SERVICE=<name>` or all services with `make ansible-deploy-services`

`make ansible-bootstrap` prompts for the remote sudo password because the bootstrap playbook uses privilege escalation.

## Secrets

Set an age recipient in `.sops.yaml`, then encrypt service secrets stored under `services/*/secrets/`.

## Validation

Use the top-level `Makefile` to validate Ansible before deployment:

```bash
make validate
make ansible-lint
```
