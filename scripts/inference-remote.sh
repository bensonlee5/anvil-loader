#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-192.168.100.133}"
REMOTE_USER="${REMOTE_USER:-bensonlee}"
REMOTE_DIR="${REMOTE_INFERENCE_DIR:-/home/bensonlee/dev/anvil-embodied-ai}"
SSH_CONNECT_TIMEOUT_SECONDS="${REMOTE_SSH_CONNECT_TIMEOUT_SECONDS:-5}"

ssh_target="${REMOTE_USER}@${REMOTE_HOST}"
printf -v remote_dir_q '%q' "${REMOTE_DIR}"

usage() {
  cat <<'EOF'
Usage: scripts/inference-remote.sh COMMAND [MODEL]

Commands:
  start [act|vla-jepa]  Select an optional model, preflight, and start inference
  stop                  Stop inference and monitor containers
  status                Show containers and the selected model
  logs                  Follow inference and monitor logs (Ctrl-C to exit)
  models                List locally available checkpoints on the inference PC
  preflight             Validate the selected model's real-robot arm routing

With no MODEL, start uses the model currently selected on the inference PC.

Environment overrides:
  REMOTE_HOST, REMOTE_USER, REMOTE_INFERENCE_DIR,
  REMOTE_SSH_CONNECT_TIMEOUT_SECONDS
EOF
}

run_remote() {
  local command="$1"
  ssh \
    -o BatchMode=yes \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT_SECONDS}" \
    "${ssh_target}" \
    "cd ${remote_dir_q} && ${command}"
}

select_model() {
  local model="$1"
  case "${model}" in
    act)
      printf '%s' './scripts/inference_model.py set lego-in-cup/act:last'
      ;;
    vla-jepa|vla_jepa|jepa)
      printf '%s' './scripts/inference_model.py set lego-in-cup/vla-jepa:last'
      ;;
    *)
      printf 'Unknown model: %s\n' "${model}" >&2
      printf '%s\n' 'Use act or vla-jepa.' >&2
      exit 2
      ;;
  esac
}

command="${1:-}"
case "${command}" in
  start)
    model="${2:-}"
    if [[ -n "${3:-}" ]]; then
      usage >&2
      exit 2
    fi

    remote_command=''
    if [[ -n "${model}" ]]; then
      remote_command="$(select_model "${model}") && "
    fi
    remote_command+='PATH=/home/bensonlee/.local/bin:$PATH ./scripts/run_inference.sh --monitor-enable up -d'
    run_remote "${remote_command}"
    ;;
  stop)
    run_remote 'docker compose stop inference inference-monitor'
    ;;
  status)
    run_remote './scripts/inference_model.py show && docker compose ps'
    ;;
  logs)
    run_remote 'docker compose logs --follow --tail=120 inference inference-monitor'
    ;;
  models)
    run_remote './scripts/inference_model.py list'
    ;;
  preflight)
    run_remote './scripts/run_inference.sh --preflight-only'
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
