# Diun

`diun` watches Docker image tags for repo-managed services and sends update notifications through `ntfy`.

Current policy:

- only labeled services are watched
- notifications report available updates
- updates are applied manually by changing image tags in git and redeploying

This keeps `asgard` in charge of host and deployment configuration while hobby projects can live elsewhere and ship prebuilt images.

`diun` now publishes to the self-hosted `ntfy` instance at `https://ntfy.noel.fyi`.

Optional hardening later:

- add authentication to `ntfy`
- give `diun` a publish token via `services/diun/secrets/ntfy-token`
