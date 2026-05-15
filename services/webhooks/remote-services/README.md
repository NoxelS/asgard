# Remote Services

Remote services are deployed by the webhook from external repositories, while
environment files and secrets live here in the infrastructure repo.

Each remote service lives in `services/webhooks/remote-services/<name>/` with:

- `repo.yaml` (required)
- `.env.example` (recommended)
- `.env` (required when `.env.example` exists)
- `secrets/` (SOPS-encrypted secrets decrypted at deploy time)

`repo.yaml` schema:

```yaml
repository: NoxelS/example
repo_url: https://github.com/NoxelS/example
compose_path: compose.yaml
edge_network: edge
edge_services: frontend,backend
rebuild_no_cache: true
```

`repository` is the `owner/name` value accepted by the webhook payload. Any valid Git ref from a configured repository may be deployed.

`edge_services` is a comma-separated list of Compose service names to connect to `edge_network` after deployment. Leave it empty to keep the stack private. `rebuild_no_cache` defaults to `true`; each webhook deploy pulls image-based services with `--ignore-buildable`, builds with `--no-cache`, then runs `docker compose down --remove-orphans` and `docker compose up -d --remove-orphans`.
