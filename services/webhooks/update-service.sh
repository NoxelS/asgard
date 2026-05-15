#!/bin/sh
set -eu

repository="${HOOK_REPOSITORY:-}"
ref="${HOOK_REF:-}"
remote_service_root="${WEBHOOK_REMOTE_SERVICE_ROOT:-/opt/remote-services}"
repo_root="${WEBHOOK_REPO_ROOT:-/opt/repos}"
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

read_yaml_value() {
  key="$1"
  file="$2"
  awk -F':[[:space:]]*' -v key="$key" '
    $1 == key {
      sub(/^[^:]+:[[:space:]]*/, "")
      gsub(/^\"|\"$/, "")
      print
      exit
    }
  ' "$file"
}

normalize_repository() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

compose() {
  docker compose \
    --project-directory "$repo_checkout" \
    --env-file "$repo_dir/.env" \
    -f "$compose_file" \
    "$@"
}

case "$repository" in
  ''|/*|*/*/*|*[!A-Za-z0-9._/-]*) fail "invalid repository; expected owner/name" ;;
esac

case "$ref" in
  ''|-*|*[!A-Za-z0-9._/@:-]*|*..*|*@\{*) fail "invalid ref" ;;
esac

[ -d "$remote_service_root" ] || fail "remote service root not found"

repository_match="$(normalize_repository "$repository")"
remote_service=""
repo_config=""
configured_repository=""

for candidate in "$remote_service_root"/*/repo.yaml; do
  [ -f "$candidate" ] || continue
  configured_repository="$(read_yaml_value repository "$candidate")"
  [ -n "$configured_repository" ] || fail "repository missing in '$candidate'"

  if [ "$(normalize_repository "$configured_repository")" = "$repository_match" ]; then
    remote_service="$(basename "$(dirname "$candidate")")"
    repo_config="$candidate"
    break
  fi
done

[ -n "$remote_service" ] || fail "repository is not allowlisted"

repo_dir="$remote_service_root/$remote_service"
repo_url="$(read_yaml_value repo_url "$repo_config")"
compose_path="$(read_yaml_value compose_path "$repo_config")"
edge_network="$(read_yaml_value edge_network "$repo_config")"
edge_services="$(read_yaml_value edge_services "$repo_config")"
rebuild_no_cache="$(read_yaml_value rebuild_no_cache "$repo_config")"

[ -n "$repo_url" ] || fail "repo_url missing in '$repo_config'"
[ -n "$compose_path" ] || compose_path="compose.yaml"
[ -n "$edge_network" ] || edge_network="edge"
[ -n "$rebuild_no_cache" ] || rebuild_no_cache="true"

case "$repo_url" in
  https://github.com/*/*|git@github.com:*/*|ssh://git@github.com/*/*) : ;;
  *) fail "repo_url must be a GitHub repository URL" ;;
esac

case "$repo_url" in
  "https://github.com/$configured_repository"|"https://github.com/$configured_repository.git"|"git@github.com:$configured_repository"|"git@github.com:$configured_repository.git"|"ssh://git@github.com/$configured_repository"|"ssh://git@github.com/$configured_repository.git") : ;;
  *) fail "repo_url does not match configured repository '$configured_repository'" ;;
esac

case "$edge_network" in
  *[!A-Za-z0-9_.-]*|'') fail "invalid edge_network" ;;
esac

case "$edge_services" in
  *[!A-Za-z0-9_.,[:space:]-]*) fail "invalid edge_services" ;;
esac

case "$rebuild_no_cache" in
  true|false) : ;;
  *) fail "rebuild_no_cache must be true or false" ;;
esac

repo_checkout="$repo_root/$remote_service"
compose_file="$repo_checkout/$compose_path"

mkdir -p "$repo_root"

notify "Deploy request accepted for '$repository' at '$ref'; updating '$remote_service'."

if [ ! -d "$repo_checkout/.git" ]; then
  git clone --no-checkout "$repo_url" "$repo_checkout" || fail "git clone failed"
else
  current_origin="$(git -C "$repo_checkout" remote get-url origin 2>/dev/null || true)"
  [ "$current_origin" = "$repo_url" ] || fail "existing checkout origin does not match configured repo_url"
fi

git -C "$repo_checkout" fetch --tags --prune origin \
  '+refs/heads/*:refs/remotes/origin/*' \
  '+refs/tags/*:refs/tags/*' || fail "git fetch failed"

case "$ref" in
  refs/heads/*)
    branch="${ref#refs/heads/}"
    git -C "$repo_checkout" checkout -B "$branch" "origin/$branch" || fail "git checkout failed"
    ;;
  refs/tags/*)
    tag="${ref#refs/tags/}"
    git -C "$repo_checkout" checkout --detach "refs/tags/$tag" || fail "git checkout failed"
    ;;
  ????????????????????????????????????????)
    git -C "$repo_checkout" checkout --detach "$ref" || fail "git checkout failed"
    ;;
  *)
    git -C "$repo_checkout" fetch origin "$ref" || fail "git fetch ref failed"
    git -C "$repo_checkout" checkout --detach FETCH_HEAD || fail "git checkout failed"
    ;;
esac

[ -f "$compose_file" ] || fail "compose file not found at '$compose_path'"
[ -f "$repo_dir/.env" ] || fail "missing .env for remote service '$remote_service'"

ln -sf "$repo_dir/.env" "$repo_checkout/.env"
if [ -d "$repo_dir/secrets" ]; then
  rm -rf "$repo_checkout/secrets"
  ln -s "$repo_dir/secrets" "$repo_checkout/secrets"
fi

compose pull --ignore-buildable || fail "docker compose pull failed"

if [ "$rebuild_no_cache" = "true" ]; then
  compose build --no-cache || fail "docker compose build failed"
else
  compose build || fail "docker compose build failed"
fi

compose down --remove-orphans || fail "docker compose down failed"

compose up -d --remove-orphans || fail "docker compose up failed"

if [ -n "$edge_services" ]; then
  docker network inspect "$edge_network" >/dev/null 2>&1 || fail "edge network '$edge_network' not found"

  for edge_service in $(printf '%s' "$edge_services" | tr ',' ' '); do
    case "$edge_service" in
      *[!A-Za-z0-9_.-]*|'') fail "invalid edge service '$edge_service'" ;;
    esac

    container_ids="$(compose ps -q "$edge_service" 2>/dev/null)" || fail "edge service '$edge_service' is not defined"
    [ -n "$container_ids" ] || fail "edge service '$edge_service' has no running container"

    for container_id in $container_ids; do
      if docker inspect --format '{{ json .NetworkSettings.Networks }}' "$container_id" | grep -Fq "\"$edge_network\""; then
        continue
      fi

      docker network connect "$edge_network" "$container_id" || fail "failed to connect '$edge_service' to '$edge_network'"
    done
  done
fi

notify "Updated remote service '$remote_service' for repository '$repository' at '$ref'."
