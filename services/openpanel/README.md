# OpenPanel

Self-hosted OpenPanel analytics for the portfolio site.

## Runtime

- Images: `lindesvard/openpanel-api:2`, `lindesvard/openpanel-dashboard:2`, `lindesvard/openpanel-worker:2`
- Data stores: `postgres:14-alpine`, `redis:7.2.5-alpine`, `clickhouse/clickhouse-server:25.10.2.65`
- Public hostname: `analytics.noel.fyi`
- Public API URL: `https://analytics.noel.fyi/api`
- Network: dashboard and API join the shared external `edge` network through Caddy

The service does not bind host ports directly. Caddy routes `/api/*` to `openpanel-api:3000` with the `/api` prefix stripped, and all other traffic to `openpanel-dashboard:3000`.

## Configuration

OpenPanel reads runtime values from `.env`. The committed `.env.example` documents all required variables.

Required values:

- `DASHBOARD_URL=https://analytics.noel.fyi`
- `API_URL=https://analytics.noel.fyi/api`
- `DATABASE_URL`
- `DATABASE_URL_DIRECT`
- `REDIS_URL`
- `CLICKHOUSE_URL`
- `COOKIE_SECRET`

`ALLOW_REGISTRATION` is set to `true` for initial setup. After the first account is created, change it to `false` and redeploy OpenPanel.

## Portfolio Tracking

Use the public API URL when configuring the portfolio OpenPanel SDK:

```js
new OpenPanel({
  apiUrl: "https://analytics.noel.fyi/api",
  clientId: "YOUR_CLIENT_ID",
});
```

## Deployment

Deploy `reverse-proxy` first on a fresh host so the shared `edge` network exists, then deploy OpenPanel and reload Caddy:

```bash
make ansible-deploy-service SERVICE=reverse-proxy
make ansible-deploy-service SERVICE=openpanel
make ansible-deploy-service SERVICE=reverse-proxy
```

## Operations

Validate the Compose file locally:

```bash
docker compose -f services/openpanel/compose.yaml config
```

OpenPanel data lives in named Docker volumes:

- `openpanel-db-data`
- `openpanel-kv-data`
- `openpanel-clickhouse-data`
- `openpanel-clickhouse-logs`

Back up Postgres and ClickHouse before image upgrades or major configuration changes.

## Upstream Docs

- Docker Compose deployment: <https://openpanel.dev/docs/self-hosting/deploy-docker-compose>
- Reverse proxy setup: <https://openpanel.dev/docs/self-hosting/reverse-proxy>
- Environment variables: <https://openpanel.dev/docs/self-hosting/environment-variables>
