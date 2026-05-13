# Portfolio

Astro portfolio site served from the prebuilt Docker image published by the portfolio repository CI/CD workflow.

## Runtime

- Image: `ghcr.io/noxels/portfolio:latest`
- Internal port: `4321`
- Public hostname: `noel.fyi`
- Network: shared external `edge` network through Caddy

The service does not bind host ports directly. Caddy routes public traffic to `portfolio:4321`.

## Deployment

Deploy `reverse-proxy` first on a fresh host so the shared `edge` network exists, then deploy the portfolio service and reload Caddy:

```bash
make ansible-deploy-service SERVICE=reverse-proxy
make ansible-deploy-service SERVICE=portfolio
make ansible-deploy-service SERVICE=reverse-proxy
```

The portfolio repository CI/CD workflow can redeploy this service through the webhook endpoint because `portfolio` is allowlisted in `services/webhooks/service-map.tsv`.
