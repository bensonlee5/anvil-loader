#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  printf 'Usage: %s {inference|quest|status}\n' "$0" >&2
}

mode="${1:-status}"
case "$mode" in
  inference|quest)
    ln -sfn ".env.config.$mode" .env.config
    ;;
  status)
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ -L .env.config ]]; then
  active_target="$(readlink .env.config)"
  active_mode="${active_target#.env.config.}"
else
  active_target=".env.config"
  active_mode="custom"
fi

profile=".env.config"
ros_domain="$(grep -E '^ROS_DOMAIN_ID=' "$profile" | tail -n1 | cut -d= -f2- || true)"
arms_config="$(grep -E '^ARMS_CONTROL_CONFIG_FILE=' "$profile" | tail -n1 | cut -d= -f2- || true)"
cyclonedds="$(grep -E '^ENABLE_CYCLONEDDS=' "$profile" | tail -n1 | cut -d= -f2- || true)"
peer_ip="$(grep -E '^CYCLONEDDS_PEER_IP=' "$profile" | tail -n1 | cut -d= -f2- || true)"
dds_iface="$(grep -E '^CYCLONEDDS_IFACE=' "$profile" | tail -n1 | cut -d= -f2- || true)"
vr_teleop="$(grep -E '^ENABLE_VR_TELEOP=' "$profile" | tail -n1 | cut -d= -f2- || true)"

printf 'Anvil mode: %s (%s -> %s)\n' "$active_mode" ".env.config" "$active_target"
printf '  ARMS_CONTROL_CONFIG_FILE=%s\n' "${arms_config:-unset}"
printf '  ROS_DOMAIN_ID=%s\n' "${ros_domain:-unset}"
printf '  ENABLE_CYCLONEDDS=%s\n' "${cyclonedds:-unset}"
printf '  CYCLONEDDS_PEER_IP=%s\n' "${peer_ip:-unset}"
printf '  CYCLONEDDS_IFACE=%s\n' "${dds_iface:-unset}"
printf '  ENABLE_VR_TELEOP=%s\n' "${vr_teleop:-unset}"

if docker compose ps --services --filter status=running 2>/dev/null | grep -q .; then
  printf '\nContainers are running. Recreate them for this mode to take effect:\n'
  printf '  docker compose up -d --force-recreate\n'
fi
