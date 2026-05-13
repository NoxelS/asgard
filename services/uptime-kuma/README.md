# Uptime Kuma

`uptime-kuma` provides public uptime monitoring at `https://uptime.noel.fyi`.

Current behavior:

- runs behind Caddy on the shared `edge` network
- stores monitor state and configuration in a persistent Docker volume
- mounts the Docker socket read-only so it can monitor container uptime
- stays publicly reachable for now, with authentication handled by Uptime Kuma itself

Docker socket access is privileged host access, even with `:ro`.

After deployment, open the site once to create the initial admin account and add monitors.
