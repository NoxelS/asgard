# Secrets

Store deploy-time secrets in this directory and keep them encrypted with SOPS.

Example:

```bash
sops --encrypt --in-place services/<name>/secrets/runtime.env
```
