# Roles

- `common`: baseline Debian package and update policy
- `ssh_hardening`: explicit sshd policy for remote access
- `firewall`: host-level UFW policy
- `docker_host`: Docker engine installation and shared host networks
- `docker_service`: deployment of repository-backed Docker Compose services

These roles support bootstrapping `yggdrasil` as a single Docker host.
