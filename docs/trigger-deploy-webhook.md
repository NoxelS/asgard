# Trigger Yggdrasil Deploy Webhook

Use this guide from another repository when a build should tell Yggdrasil to check out that repository and deploy its Docker Compose stack. Deployments only target repositories allowlisted under `services/webhooks/remote-services/`.

## Required Setup

1. Add `services/webhooks/remote-services/<name>/repo.yaml` in this infrastructure repo.
2. Add `.env` and optional SOPS-encrypted `secrets/` beside that `repo.yaml`.
3. Deploy the `webhooks` service after changing the allowlist.
4. Store the webhook HMAC secret in the source repository's GitHub Actions secrets.

Use this GitHub secret name in side-project repositories:

```text
YGGDRASIL_WEBHOOK_SECRET
```

Yes, the secret should be stored in GitHub Actions secrets. Do not commit it to the side-project repository, print it in logs, or pass it as a plain query parameter.

## Endpoint

```text
POST https://hooks.noel.fyi/hooks/deploy
```

The webhook only accepts signed `POST` requests. Any valid Git ref from an allowlisted repository may be requested.

## Payload

Send metadata only. Do not send code or shell commands.

```json
{
  "repository": "NoxelS/portfolio",
  "ref": "refs/heads/main"
}
```

Fields:

| Field | Required | Meaning |
| --- | --- | --- |
| `repository` | Yes | Allowlisted `owner/name` repository from `repo.yaml` |
| `ref` | Yes | Git ref to check out, such as `refs/heads/main`, `refs/tags/v1.0.0`, or a commit SHA |

## Signature

Sign the exact raw JSON request body with HMAC-SHA256 and send it as:

```text
X-Hub-Signature-256: sha256=<hex digest>
```

The webhook rejects requests if the signature does not match `YGGDRASIL_WEBHOOK_SECRET`.

## GitHub Actions Example

Add this step after the image has been pushed to the registry or after the repository ref is ready to deploy:

```yaml
- name: Trigger Yggdrasil deploy
  if: github.ref == 'refs/heads/main'
  env:
    WEBHOOK_SECRET: ${{ secrets.YGGDRASIL_WEBHOOK_SECRET }}
    WEBHOOK_URL: https://hooks.noel.fyi/hooks/deploy
    REPOSITORY: ${{ github.repository }}
  run: |
    set -euo pipefail

    payload=$(jq -cn \
      --arg repository "$REPOSITORY" \
      --arg ref "$GITHUB_REF" \
      '{repository: $repository, ref: $ref}')

    signature="sha256=$(printf '%s' "$payload" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -binary | xxd -p -c 256)"

    curl --fail-with-body \
      --request POST \
      --header "Content-Type: application/json" \
      --header "X-Hub-Signature-256: $signature" \
      --data "$payload" \
      "$WEBHOOK_URL"
```

## Agent Checklist

When adding this to a side-project repository:

1. Confirm the Docker image is pushed before the webhook step runs.
2. Set `REPOSITORY` to the allowlisted `owner/name` value in `services/webhooks/remote-services/<name>/repo.yaml`.
3. Ensure `.env` and optional encrypted secrets exist in `services/webhooks/remote-services/<name>/`.
4. Use `secrets.YGGDRASIL_WEBHOOK_SECRET` for signing.
5. Never include the secret in workflow logs.

## Expected Result

A successful request returns:

```text
Deployment request accepted
```

The `webhooks` service sends ntfy monitoring messages when the request is accepted, rejected, and completed.
