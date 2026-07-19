#!/usr/bin/env bash
set -Eeuo pipefail

AI_HUB_ROOT="${AI_HUB_ROOT:-/srv/ai-hub}"
AI_HUB_NETWORK="${AI_HUB_NETWORK:-ai-network}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root: sudo $0" >&2
  exit 1
fi

install -d -m 0750 \
  "${AI_HUB_ROOT}/hermes/data" \
  "${AI_HUB_ROOT}/hermes/workspace" \
  "${AI_HUB_ROOT}/openwebui/data" \
  "${AI_HUB_ROOT}/ollama/models" \
  "${AI_HUB_ROOT}/postgres/data" \
  "${AI_HUB_ROOT}/redis/data" \
  "${AI_HUB_ROOT}/n8n/data" \
  "${AI_HUB_ROOT}/backups"

if ! docker network inspect "${AI_HUB_NETWORK}" >/dev/null 2>&1; then
  docker network create --driver bridge "${AI_HUB_NETWORK}" >/dev/null
  echo "Rede ${AI_HUB_NETWORK} criada."
else
  echo "Rede ${AI_HUB_NETWORK} já existe."
fi

echo "Estrutura criada em ${AI_HUB_ROOT}."
