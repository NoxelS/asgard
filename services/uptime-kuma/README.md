# Uptime Kuma

`uptime-kuma` provides public uptime monitoring at `https://uptime.noel.fyi`.

Current behavior:

- runs behind Caddy on the shared `edge` network
- stores monitor state and configuration in a persistent Docker volume
- stays publicly reachable for now, with authentication handled by Uptime Kuma itself

After deployment, open the site once to create the initial admin account and add monitors.
