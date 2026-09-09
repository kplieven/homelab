#!/bin/bash
#
# Recreate every container that shares gluetun's network namespace.
#
# Those containers are pinned to gluetun's namespace by container ID, not by
# name. Recreating gluetun (an image pull, a compose up after an edit) leaves
# them attached to an ID that no longer exists. The failure is silent: they keep
# reporting "running" while having no network at all, and their WebUIs go dead.
#
# `docker restart` CANNOT fix this -- the dead ID is baked into the container's
# HostConfig, so restarting just retries the same doomed join and the container
# stops. Only recreating re-resolves "container:gluetun" from name to live ID,
# which means going through each dependent's own compose stack.
#
# Compose used to handle this automatically when everything lived in one
# project; now that the consumers are spread across services/media-stack and
# services/books-stack, nothing does. Run this after any gluetun recreate.

set -uo pipefail

docker inspect gluetun >/dev/null 2>&1 || {
    echo "ERROR: gluetun container not found -- start services/gluetun first." >&2
    exit 1
}
if [[ "$(docker inspect -f '{{.State.Running}}' gluetun)" != "true" ]]; then
    echo "ERROR: gluetun is not running -- start it before its dependents." >&2
    exit 1
fi
gluetun_id="$(docker inspect -f '{{.Id}}' gluetun)"

label() { docker inspect -f "{{index .Config.Labels \"$2\"}}" "$1" 2>/dev/null; }

# Collect dependents grouped by compose project: "project<TAB>workdir<TAB>service"
rows=()
while read -r name; do
    [[ -z "$name" || "$name" == "gluetun" ]] && continue
    mode="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$name" 2>/dev/null)"
    [[ "$mode" == container:* ]] || continue

    if [[ "${mode#container:}" == "$gluetun_id" ]] \
       && [[ "$(docker inspect -f '{{.State.Running}}' "$name")" == "true" ]]; then
        echo "OK (already on the live gluetun): $name"
        continue
    fi

    proj="$(label "$name" com.docker.compose.project)"
    wdir="$(label "$name" com.docker.compose.project.working_dir)"
    svc="$(label "$name" com.docker.compose.service)"
    if [[ -z "$proj" || -z "$wdir" || -z "$svc" ]]; then
        echo "WARN: $name is stale but not compose-managed -- recreate it by hand." >&2
        continue
    fi
    rows+=("$proj	$wdir	$svc")
done < <(docker ps -a --format '{{.Names}}')

if (( ${#rows[@]} == 0 )); then
    echo "Nothing stale. All namespace consumers are on the live gluetun."
    exit 0
fi

rc=0
for proj in $(printf '%s\n' "${rows[@]}" | cut -f1 | sort -u); do
    wdir="$(printf '%s\n' "${rows[@]}" | awk -F'\t' -v p="$proj" '$1==p{print $2; exit}')"
    mapfile -t svcs < <(printf '%s\n' "${rows[@]}" | awk -F'\t' -v p="$proj" '$1==p{print $3}' | sort -u)

    echo "Recreating in project '$proj' ($wdir): ${svcs[*]}"
    if ! (cd "$wdir" && docker compose up -d --force-recreate "${svcs[@]}"); then
        echo "  FAILED: project $proj" >&2
        rc=1
    fi
done
exit $rc
