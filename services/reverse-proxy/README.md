# Reverse Proxy

Shared Caddy entrypoint for Docker services on `yggdrasil`.

Deploy this service first so the host is ready to terminate HTTPS for Cloudflare in `Full (strict)` mode.

Setup requirements:

1. Create `.env` from `.env.example` and set `CADDY_SITE_ADDRESSES` to the exact hostnames and wildcards covered by your Cloudflare Origin CA certificate.
2. Create `services/reverse-proxy/secrets/origin.crt` and `services/reverse-proxy/secrets/origin.key` with the Cloudflare Origin CA certificate and private key.
3. Encrypt both files with SOPS before committing them.

This stack now routes `ntfy.noel.fyi` to the self-hosted `ntfy` service.

Any additional public service should stay off host ports, join the shared `edge` network, and get an explicit route in `services/reverse-proxy/Caddyfile`.
