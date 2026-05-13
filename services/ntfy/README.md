# Ntfy

`ntfy` is a core infrastructure service on `yggdrasil`.

It provides a self-hosted notification endpoint at `https://ntfy.noel.fyi` and is currently used by `diun` for image update alerts.

Current behavior:

- runs behind Caddy on the shared `edge` network
- keeps a persistent message cache on disk
- trusts proxy headers from Caddy via `NTFY_BEHIND_PROXY=true`
- stays open for now so `diun` can publish without additional credentials

If you later want to make the instance private, add auth settings and give `diun` a publish token.
