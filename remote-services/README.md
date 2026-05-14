# Remote Services

Remote services are deployed from external repositories, while environment files
and secrets live here in the infrastructure repo.

Each remote service lives in `remote-services/<name>/` with:

- `repo.yaml` (required)
- `.env.example` (recommended)
- `.env` (required when `.env.example` exists)
- `secrets/` (SOPS-encrypted secrets decrypted at deploy time)

`repo.yaml` schema:

```yaml
repo_url: https://github.com/NoxelS/example
branch: main
compose_path: compose.yaml
```

Only repositories under `github.com/NoxelS` are allowed.
