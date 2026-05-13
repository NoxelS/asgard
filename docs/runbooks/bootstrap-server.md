# Bootstrap Server

Bootstrap `yggdrasil` in this order.

## 1. Update the inventory

Set the real host addresses in `bootstrap/ansible/inventory/asgard/hosts.yml`.

## 2. Bootstrap the host

```bash
make ansible-bootstrap
```

This applies package updates, SSH hardening, firewall rules, Docker installation, and shared Docker network creation.
The bootstrap target prompts for the remote sudo password because the playbook runs with `become: true`.

## 3. Deploy the reverse proxy

Before deployment, add your Cloudflare Origin CA certificate and private key as encrypted files under `services/reverse-proxy/secrets/`.

```bash
make ansible-deploy-service SERVICE=reverse-proxy
```

## 4. Deploy ntfy

Deploy `ntfy` first so `diun` has a self-hosted notification endpoint to publish to:

```bash
make ansible-deploy-service SERVICE=ntfy
```

## 5. Deploy diun

Deploy `diun` early so the host starts reporting available image updates:

```bash
make ansible-deploy-service SERVICE=diun
```

## 6. Deploy application services

```bash
make ansible-deploy-service SERVICE=<name>
```

Use `make ansible-deploy-services` to deploy every service with a `compose.yaml`.
