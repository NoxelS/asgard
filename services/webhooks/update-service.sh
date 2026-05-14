#!/bin/sh
set -eu

repository="${HOOK_REPOSITORY:-}"
ref="${HOOK_REF:-}"
image="${HOOK_IMAGE:-}"
tag="${HOOK_TAG:-}"
service_root="${WEBHOOK_SERVICE_ROOT:-/opt/services}"
service_map="${WEBHOOK_SERVICE_MAP:-/config/service-map.tsv}"
remote_service_root="${WEBHOOK_REMOTE_SERVICE_ROOT:-/opt/remote-services}"
remote_repo_root="${WEBHOOK_REMOTE_REPO_ROOT:-/opt/remote-repos}"
ntfy_url="${WEBHOOK_NTFY_URL:-}"

notify() {
  [ -n "$ntfy_url" ] || return 0
  curl -fsS \
    -H "Title: Yggdrasil webhook" \
    -H "Tags: hook,whale" \
    -d "$1" \
    "$ntfy_url" >/dev/null || true
}

fail() {
  notify "Rejected deploy request for repository '${repository:-unknown}': $1"
  printf '%s\n' "$1" >&2
  exit 1
}

case "$repository" in
  ''|*[!A-Za-z0-9._-]*) fail "invalid repository" ;;
esac

  case "$repository" in
    *.*|*/*) fail "invalid repository owner" ;;
  esac

[ "$ref" = "refs/heads/main" ] || fail "unsupported ref '$ref'"
[ -f "$service_map" ] || fail "service map not found"

mapping="$(awk -v repo="$repository" '
  $0 !~ /^#/ && NF >= 3 && $1 == repo { print $2 "\t" $3 "\t" $4; found=1; exit }
  END { if (!found) exit 1 }
' "$service_map")" || fail "repository is not allowlisted"

compose_project="$(printf '%s' "$mapping" | cut -f1)"
compose_service="$(printf '%s' "$mapping" | cut -f2)"
remote_service="$(printf '%s' "$mapping" | cut -f3)"

case "$compose_project:$compose_service" in
  *[!A-Za-z0-9._:-]*) fail "invalid service mapping" ;;
esac

if [ -n "$remote_service" ]; then
  case "$remote_service" in
    *[!A-Za-z0-9._-]*) fail "invalid remote service mapping" ;;
  esac

  repo_dir="$remote_service_root/$remote_service"
  repo_config="$repo_dir/repo.yaml"

  [ -f "$repo_config" ] || fail "remote service config not found for '$remote_service'"

  repo_url="$(awk -F': ' '$1 == "repo_url" { sub(/^[^:]+: /, ""); print; exit }' "$repo_config")"
  branch="$(awk -F': ' '$1 == "branch" { sub(/^[^:]+: /, ""); print; exit }' "$repo_config")"
  compose_path="$(awk -F': ' '$1 == "compose_path" { sub(/^[^:]+: /, ""); print; exit }' "$repo_config")"

  [ -n "$repo_url" ] || fail "repo_url missing in '$repo_config'"
  [ -n "$branch" ] || branch="main"
  [ -n "$compose_path" ] || compose_path="compose.yaml"

  case "$repo_url" in
    https://github.com/NoxelS/*) : ;;
    git@github.com:NoxelS/*) : ;;
    ssh://git@github.com/NoxelS/*) : ;;
    *ghcr.io/noxels/*) fail "repo_url must be a git URL for NoxelS, not an image" ;;
    *github.com/*) fail "repo_url must be under github.com/NoxelS" ;;
    *) fail "repo_url must be a github.com/NoxelS repository" ;;
  esac

  repo_checkout="$remote_repo_root/$remote_service"
  compose_file="$repo_checkout/$compose_path"

  mkdir -p "$remote_repo_root" "$remote_service_root"

  if [ ! -d "$repo_checkout/.git" ]; then
    git clone --branch "$branch" --depth 1 "$repo_url" "$repo_checkout" || fail "git clone failed"
  else
    git -C "$repo_checkout" fetch origin "$branch" --depth 1 || fail "git fetch failed"
    git -C "$repo_checkout" checkout "$branch" || fail "git checkout failed"
    git -C "$repo_checkout" reset --hard "origin/$branch" || fail "git reset failed"
  fi

  [ -f "$compose_file" ] || fail "compose file not found at '$compose_path'"
  [ -f "$repo_dir/.env" ] || fail "missing .env for remote service '$remote_service'"

  ln -sf "$repo_dir/.env" "$repo_checkout/.env"
  if [ -d "$repo_dir/secrets" ]; then
    ln -sf "$repo_dir/secrets" "$repo_checkout/secrets"
  fi

  notify "Accepted deploy request for '$repository' from '$ref'${image:+ image '$image'}${tag:+ tag '$tag'}; updating remote '$remote_service'."

  docker compose --project-directory "$repo_checkout" --env-file "$repo_dir/.env" -f "$compose_file" pull
  docker compose --project-directory "$repo_checkout" --env-file "$repo_dir/.env" -f "$compose_file" up -d

  notify "Updated remote service '$remote_service' for repository '$repository'."
else
  project_dir="$service_root/$compose_project"
  [ -f "$project_dir/compose.yaml" ] || fail "compose file not found for '$compose_project'"

  notify "Accepted deploy request for '$repository' from '$ref'${image:+ image '$image'}${tag:+ tag '$tag'}; updating '$compose_project/$compose_service'."

  docker compose --project-directory "$project_dir" pull "$compose_service"
  docker compose --project-directory "$project_dir" up -d --no-deps "$compose_service"

  notify "Updated '$compose_project/$compose_service' for repository '$repository'."
fi
