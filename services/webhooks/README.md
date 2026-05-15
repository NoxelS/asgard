# Webhooks

`webhooks` receives signed deployment callbacks at `https://hooks.noel.fyi/hooks/deploy`, checks out allowlisted Git repositories under `/opt/repos`, and deploys their Docker Compose stacks. Repository allowlisting, environment files, and secrets live under `services/webhooks/remote-services/`.

## Request Contract

Send a `POST` request with JSON metadata only:

```json
{
  "repository": "NoxelS/portfolio",
  "ref": "refs/heads/main"
}
```

The request must include `X-Hub-Signature-256` using the SOPS-encrypted secret in `secrets/webhook_secret`:

```text
sha256=<hex hmac of raw request body>
```

## Repository Allowlist

Each repository must be defined under `services/webhooks/remote-services/<name>/repo.yaml`:

```yaml
repository: NoxelS/portfolio
repo_url: https://github.com/NoxelS/portfolio
compose_path: compose.yaml
edge_network: edge
edge_services: frontend,backend
rebuild_no_cache: true
```

The webhook rejects repositories that are not present in these definitions. Any valid Git ref from an allowlisted repository may be requested.

Use `edge_services` to expose specific Compose services on the external Docker network used by Caddy. Do not list internal-only services such as databases or Redis.

For local testing, use:

```bash
make webhook NoxelS/portfolio REF=refs/heads/main
```

## Security Notes

This service mounts `/var/run/docker.sock`, which is privileged access to the Docker host. Keep the hook secret private, use HMAC signatures, and keep `services/webhooks/remote-services/` narrow.

## Monitoring

Accepted, rejected, and completed hook executions publish notifications to `ntfy` at the topic configured by `WEBHOOK_NTFY_URL`.
