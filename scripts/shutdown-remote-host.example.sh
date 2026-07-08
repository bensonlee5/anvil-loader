#!/usr/bin/env bash
set -euo pipefail

REMOTE_NAME="${REMOTE_NAME:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_SHUTDOWN_TIMEOUT_SECONDS="${REMOTE_SHUTDOWN_TIMEOUT_SECONDS:-60}"
REMOTE_SSH_CONNECT_TIMEOUT_SECONDS="${REMOTE_SSH_CONNECT_TIMEOUT_SECONDS:-5}"
REMOTE_SHUTDOWN_CMD="${REMOTE_SHUTDOWN_CMD:-sudo /usr/sbin/shutdown -h now}"

ssh_target="${REMOTE_USER}@${REMOTE_HOST}"

is_reachable() {
  ping -c 1 -W 1 "${REMOTE_HOST}" >/dev/null 2>&1
}

if [[ -z "${REMOTE_HOST}" || -z "${REMOTE_USER}" ]]; then
  printf '%s\n' "REMOTE_HOST and REMOTE_USER must be set." >&2
  exit 2
fi

if ! is_reachable; then
  printf '%s\n' "${REMOTE_NAME:-Remote host} is already unreachable at ${REMOTE_HOST}."
  exit 0
fi

printf '%s\n' "Requesting ${REMOTE_NAME:-remote host} shutdown at ${ssh_target}..."

set +e
ssh \
  -o BatchMode=yes \
  -o ConnectTimeout="${REMOTE_SSH_CONNECT_TIMEOUT_SECONDS}" \
  "${ssh_target}" \
  "${REMOTE_SHUTDOWN_CMD}"
ssh_status=$?
set -e

if (( ssh_status != 0 && ssh_status != 255 )); then
  printf '%s\n' "Shutdown command failed with SSH exit status ${ssh_status}." >&2
  exit "${ssh_status}"
fi

deadline=$((SECONDS + REMOTE_SHUTDOWN_TIMEOUT_SECONDS))
while is_reachable; do
  if (( SECONDS >= deadline )); then
    printf '%s\n' "Timed out waiting for ${REMOTE_NAME:-remote host} to stop responding at ${REMOTE_HOST}." >&2
    exit 1
  fi
  sleep 2
done

printf '%s\n' "${REMOTE_NAME:-Remote host} is offline."
