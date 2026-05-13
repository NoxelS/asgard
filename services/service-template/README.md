# Service Template

Use this structure for new Docker-backed services.

Recommended files:

- `compose.yaml`
- `.env`
- `Dockerfile` when you also build locally, otherwise prefer a pinned `image:`
- `.env.example`
- `secrets/`
- `README.md`

For now, services are expected to stay internal-only unless you intentionally wire them into the shared Caddy configuration.

Create `.env` from `.env.example` before deployment, and keep only sensitive runtime values under `secrets/`.

When you later expose a service publicly, attach it to the shared `edge` network and add an explicit route for it in `services/reverse-proxy/Caddyfile`.

If a service should be watched for image updates, add `diun.enable=true`. That lets `diun` notify you when a newer image is available without auto-updating the container.
