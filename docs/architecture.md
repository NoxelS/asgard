# Architecture

## Model

`Git -> Ansible -> Docker Engine -> Compose services`

`Caddy -> shared edge routing for public services`

`Diun -> image update notifications for labeled services`

`Ntfy -> self-hosted notification endpoint for infrastructure alerts`

## Principles

- Git is the source of truth for host and service configuration.
- The host is rebuilt from declarative config where possible.
- Runtime application data is not treated as part of git-managed state.
- Stateful applications must bring their own backup strategy.

## Current Scope

- Single host: `yggdrasil`
- Debian 12
- Docker Engine with the Compose plugin
- Caddy on the public IP for shared ingress
- No centralized backup automation yet

## Layers

### Host Configuration

- Debian hardening, package updates, firewalling, and Docker installation via Ansible.

### Runtime

- Docker Engine runs repository-backed Compose projects from `services/*`.
- Shared ingress is handled by Caddy on the `edge` Docker network.
- `ntfy` is exposed through Caddy at `ntfy.noel.fyi`.
- `diun` watches labeled containers and reports available image updates through `ntfy`.

### Delivery

- Ansible bootstraps the host first, then deploys service directories onto `yggdrasil`.
- Service secrets remain encrypted in git and are decrypted during deployment.
- Hobby projects are expected to arrive as prebuilt images; this repo owns only the runtime configuration needed to run them.

## Naming

- Host and shared infrastructure names use Norse/mythological names where useful.
- Individual services keep their product names for operational clarity.
