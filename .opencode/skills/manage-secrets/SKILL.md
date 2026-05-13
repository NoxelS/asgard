---
name: manage-secrets
description: Encrypt, decrypt, and rotate service secrets using SOPS and age
license: MIT
metadata:
  audience: operators
  workflow: secret-management
---

## What I do

I handle all secret management operations for Yggdrasil services using SOPS + age encryption:

- Encrypt new secrets (API keys, passwords, certificates) for a service
- Decrypt secrets for local review or emergency access
- Rotate secrets (e.g., when a key is compromised)
- Validate that secret files are properly encrypted
- Manage the age encryption key and SOPS configuration
- Deploy secrets safely to yggdrasil without exposing plaintext in git

## When to use me

Use this when you:
- Add a new service that requires API keys or passwords
- Need to update credentials without changing code
- Rotate a compromised secret key
- Debug secret-related deployment failures
- Set up age encryption for the first time
- Need to recover or migrate secrets

## How I work

### Setup Phase (First Time)
Nothing todo.

### Encryption Phase
1. **Create secret file**: Create plaintext file with secrets (e.g., `api_key: "value"`)
2. **Encrypt with SOPS**: Run `sops -e` to encrypt the file
3. **Save encrypted file**: Move to `services/<name>/secrets/` in git
4. **Verify in git**: Confirm encrypted content is committed, never plaintext

### Deployment Phase
1. **Sync secrets**: Ansible copies encrypted files to yggdrasil
2. **Decrypt on host**: During deployment, secrets are decrypted in-place
3. **Inject into containers**: SOPS-encrypted env vars become container environment
4. **No logs**: Plaintext secrets never appear in logs or git history

### Rotation Phase
1. **Identify old secret**: Locate the encrypted file in `services/<name>/secrets/`
2. **Create new secret**: Generate replacement credential (e.g., new API key)
3. **Update encrypted file**: Use SOPS to update the encrypted value
4. **Deploy update**: Run `make ansible-deploy-service SERVICE=<name>`
5. **Revoke old secret**: On the provider side, disable the old credential

## Key files and locations

**Age key** (keep safe, never commit):
```
~/.../sops/age/keys.txt    # Your private encryption key
```

**SOPS configuration** (in repo root):
```
.sops.yaml                     # Specifies age recipient and rules
```

**Service secrets** (encrypted, safe to commit):
```
services/<name>/secrets/*.yaml # Encrypted secrets for a service
```

**Docker Compose** (references secrets):
```
services/<name>/compose.yaml   # Uses env_file: secrets/... or env from container
```

## Common workflows

**Add a new secret to a service**
```
Ask me to add an API key secret to the ntfy service
I'll create an encrypted file and show you how to reference it in compose.yaml
```

**Rotate a compromised credential**
```
My API key was exposed, help me rotate it
I'll update the encrypted secret file and redeploy the service
```

**Deploy secrets safely**
```
I've added secrets to a service, how do I deploy?
I'll show you how Ansible decrypts and injects them at deployment time
```

**Emergency secret access**
```
I need to see what the current API key is for debugging
I'll temporarily decrypt the file and show you the value
```

**Backup/migrate secrets**
```
I'm moving infrastructure to a new server
I'll help you export secrets and set up age key on the new machine
```

## Security best practices

✓ **Do**:
- Store age private key securely (600 permissions, not in git)
- Use `.gitignore` to prevent plaintext secrets from being committed
- Rotate credentials regularly, especially after staff changes
- Keep `.sops.yaml` in git (it's safe—contains only recipient fingerprint)
- Use SOPS for all secrets: API keys, DB passwords, certs, tokens

✗ **Don't**:
- Commit plaintext secrets to git (ever)
- Share your age private key
- Use the same secret across multiple services
- Store secrets in docker-compose.yaml (use env_file or SOPS)
- Paste secrets in logs or debug output

## References

- **SOPS project**: https://github.com/mozilla/sops
- **Age project**: https://github.com/FiloSottile/age
- **SOPS + age guide**: https://github.com/mozilla/sops#encrypting-using-age
- **repo configuration**: `.sops.yaml` — defines encryption rules
- **Secrets directory**: `services/*/secrets/` — where to store encrypted files
- **Docker Compose**: `services/*/compose.yaml` — how to reference secrets

---

**Security note**: Your age private key is the only thing protecting these secrets. Back it up securely and never share it. If compromised, rotate all secrets immediately.
