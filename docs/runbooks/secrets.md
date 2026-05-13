# Secrets Workflow

## 1. Generate an age key pair

```bash
age-keygen -o age.agekey
```

Record the public key shown by the command and replace the placeholder recipient in `.sops.yaml`.

## 2. Update `.sops.yaml`

Replace:

```yaml
age: age1replacewithrealpublickey
```

with your real age public key.

## 3. Store service secrets in the repository

Place encrypted service secrets under `services/<name>/secrets/`.

```bash
sops --encrypt --in-place services/<name>/secrets/runtime.env
```

For the reverse proxy, store your Cloudflare Origin CA certificate and key as:

```bash
services/reverse-proxy/secrets/origin.crt
services/reverse-proxy/secrets/origin.key
```

If you later authenticate `diun` against the self-hosted `ntfy` instance, store that token under:

```bash
services/diun/secrets/ntfy-token
```

## 4. Deploy secrets with Ansible

During `make ansible-deploy-service` or `make ansible-deploy-services`, Ansible decrypts these files locally and writes the plaintext versions to `/opt/services/<name>/secrets/` on `yggdrasil`.

## 5. Re-encrypt after changes

```bash
sops --encrypt --in-place services/<name>/secrets/runtime.env
```
