# Onboarding

## Expected Tooling

- `uv`
- `ansible`
- `sops`
- `age`

## High-Level Workflow

1. Provision the host outside this repository.
2. Update `bootstrap/ansible/inventory/asgard/hosts.yml` with the real host details.
3. Bootstrap `yggdrasil` with Ansible.
4. Add or update services under `services/*`.
5. Encrypt any service secrets under `services/*/secrets/`.
6. Deploy services with the Ansible service playbook.

## Secrets

- Secrets committed to Git must be encrypted with SOPS.
- Age is the default encryption mechanism.

## Current Deferrals

- No centralized container orchestration
- No centralized backup automation
- No automated rollback flow beyond Compose redeploys
