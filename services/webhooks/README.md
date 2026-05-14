# Webhooks

`webhooks` receives signed deployment callbacks at `https://hooks.noel.fyi/hooks/deploy` and recreates allowlisted Docker Compose services after new images are published. It can deploy either local services in this repo or remote services checked out from allowlisted repositories.

## Request Contract

Send a `POST` request with JSON metadata only:

```json
{
  "repository": "ntfy",
  "ref": "refs/heads/main",
  "image": "binwiederhier/ntfy",
  "tag": "v2.22.0"
}
```

The request must include `X-Hub-Signature-256` using the SOPS-encrypted secret in `secrets/webhook_secret`:

```text
sha256=<hex hmac of raw request body>
```

## Service Allowlist

`service-map.tsv` maps incoming repository names to Compose projects and services. When a fourth column is set, the webhook treats it as a `remote-services/<name>` entry and deploys from the repo checkout defined there. The script only updates entries in this file and rejects arbitrary repository names or paths.

## Security Notes

This service mounts `/var/run/docker.sock`, which is privileged access to the Docker host. Keep the hook secret private, use HMAC signatures, keep `service-map.tsv` narrow, and restrict remote service repos to `github.com/NoxelS/*`.

## Monitoring

Accepted, rejected, and completed hook executions publish notifications to `ntfy` at the topic configured by `WEBHOOK_NTFY_URL`.
