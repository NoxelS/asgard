# TODO

## Goal

Keep `asgard` as the core infrastructure repo for `yggdrasil`, while hobby projects and other application services are delivered as Docker images and only configured/deployed from this repo.

## Diun Plan

1. Define the update-notification approach

- Use `diun` for image update detection and notifications.
- Do not use automatic image replacement for hobby projects by default.
- Treat `diun` as the safe replacement for a `watchtower`-style update workflow: detect first, review, then redeploy intentionally.

2. Add a dedicated service for `diun`

- Create `services/diun/`.
- Add `compose.yaml`.
- Add `.env` and `.env.example` for non-secret runtime config.
- Add `secrets/` only if notification credentials are required.
- Add a small `README.md` that explains what `diun` watches and how alerts are delivered.

3. Configure `diun` to watch the right containers/images

- Watch only services managed by this repo.
- Prefer label-based inclusion so unrelated containers on the host are ignored.
- Decide on one clear convention for monitored services, for example a Docker label such as `diun.enable=true`.
- Make the service template include the monitoring label convention for future hobby projects.

4. Decide notification targets

- Pick the first notification channel for image update alerts.
- Good options: email, ntfy, Gotify, Matrix, Slack, or Discord.
- Store any notification credentials with SOPS under `services/diun/secrets/`.

5. Define image lifecycle policy

- `diun` only reports available updates.
- Image upgrades happen by explicitly changing config and redeploying from this repo.
- Keep infrastructure services and hobby projects on pinned image tags where practical.
- Avoid floating `latest` tags for anything important.

6. Clarify repo responsibility boundaries

- `asgard` owns:
  - host bootstrap
  - reverse proxy
  - monitoring/utility services like `diun`
  - deployment configuration for hobby projects
- Hobby project source code can live elsewhere.
- This repo should only carry the Docker image references, runtime configuration, secrets, and routing needed to run those projects.

7. Update the service template for future hobby projects

- Add the expected `diun` label convention.
- Document that services are normally deployed from prebuilt images.
- Keep public exposure disabled by default.
- Document how a hobby project is onboarded when its image is ready.

8. Add docs/runbook coverage

- Document how `diun` works.
- Document how to onboard a new hobby project image into `services/<name>/`.
- Document how to respond to update notifications.
- Document the difference between:
  - infrastructure services managed directly here
  - hobby projects consumed as images and configured here

9. Validate the operational flow

- Bootstrap host.
- Deploy reverse proxy.
- Deploy `diun`.
- Add one sample image-based hobby project.
- Confirm `diun` can see the monitored image and send notifications.

## Suggested Implementation Order

1. Add `services/diun/`
2. Add label convention for monitored services
3. Update `services/service-template/`
4. Add docs for image-based hobby project onboarding
5. Deploy and test notifications
