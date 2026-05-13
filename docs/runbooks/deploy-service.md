# Deploy Service

## Layout

Each deployable project should contain at least:

```text
services/<name>/
  compose.yaml
  .env
  README.md
```

Optional files:

```text
Dockerfile
.env.example
secrets/
```

Create `.env` from `.env.example` before deploying. Keep non-secret routing and Compose variables there, and keep sensitive values under `secrets/` encrypted with SOPS.

For hobby projects, prefer `image:` with a pinned tag in `compose.yaml`. This repo is the runtime/deployment layer, not necessarily the source-code home of each project.

## Deploy one service

```bash
make ansible-deploy-service SERVICE=<name>
```

## Deploy all services

```bash
make ansible-deploy-services
```

## Image update monitoring

Add `diun.enable=true` to services that should be monitored for new image releases.

`diun` only sends notifications. Applying the update still happens intentionally by changing the image tag in git and redeploying.

Core infrastructure services such as `reverse-proxy`, `ntfy`, and `diun` follow the same image pinning rule.

## Routing

Public services should not publish host ports directly.

When you later expose a service, attach it to the shared `edge` network and add an explicit `reverse_proxy` route for it in `services/reverse-proxy/Caddyfile`.
