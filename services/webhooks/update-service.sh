#!/bin/sh
set -eu

repository="${HOOK_REPOSITORY:-}"
ref="${HOOK_REF:-}"
image="${HOOK_IMAGE:-}"
tag="${HOOK_TAG:-}"
service_root="${WEBHOOK_SERVICE_ROOT:-/opt/services}"
service_map="${WEBHOOK_SERVICE_MAP:-/config/service-map.tsv}"
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

[ "$ref" = "refs/heads/main" ] || fail "unsupported ref '$ref'"
[ -f "$service_map" ] || fail "service map not found"

mapping="$(awk -v repo="$repository" '
  $0 !~ /^#/ && NF >= 3 && $1 == repo { print $2 "\t" $3; found=1; exit }
  END { if (!found) exit 1 }
' "$service_map")" || fail "repository is not allowlisted"

compose_project="$(printf '%s' "$mapping" | cut -f1)"
compose_service="$(printf '%s' "$mapping" | cut -f2)"
project_dir="$service_root/$compose_project"

case "$compose_project:$compose_service" in
  *[!A-Za-z0-9._:-]*) fail "invalid service mapping" ;;
esac

[ -f "$project_dir/compose.yaml" ] || fail "compose file not found for '$compose_project'"

notify "Accepted deploy request for '$repository' from '$ref'${image:+ image '$image'}${tag:+ tag '$tag'}; updating '$compose_project/$compose_service'."

docker compose --project-directory "$project_dir" pull "$compose_service"
docker compose --project-directory "$project_dir" up -d --no-deps "$compose_service"

notify "Updated '$compose_project/$compose_service' for repository '$repository'."
