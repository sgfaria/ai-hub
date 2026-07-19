#!/usr/bin/env bash
set -Eeuo pipefail

AI_HUB_ROOT="${AI_HUB_ROOT:-/srv/ai-hub}"
BACKUP_DIR="${BACKUP_DIR:-${AI_HUB_ROOT}/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-n8n}"
POSTGRES_USER="${POSTGRES_USER:-n8n}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-hub-backup.XXXXXX")"
ARCHIVE="${BACKUP_DIR}/ai-hub-${STAMP}.tar.gz"
DB_DUMP="${BACKUP_DIR}/ai-hub-${STAMP}.postgres.dump"
CHECKSUMS="${BACKUP_DIR}/ai-hub-${STAMP}.sha256"

cleanup() {
  rm -rf -- "${WORK_DIR}"
}
trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root: sudo $0" >&2
  exit 1
fi

if [[ ! -f "${AI_HUB_ROOT}/.ai-hub-root" ]]; then
  echo "Diretório não inicializado pelo AI Hub: ${AI_HUB_ROOT}" >&2
  echo "Execute scripts/bootstrap-host.sh antes do primeiro backup." >&2
  exit 1
fi

install -d -m 0750 "${BACKUP_DIR}"

echo "Gerando dump consistente do PostgreSQL..."
docker exec "${POSTGRES_CONTAINER}" \
  pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -Fc > "${DB_DUMP}"

mapfile -t RUNNING_CONTAINERS < <(
  for name in hermes-agent open-webui n8n redis grafana prometheus; do
    if [[ "$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || true)" == "true" ]]; then
      printf '%s\n' "${name}"
    fi
  done
)

restart_containers() {
  if ((${#RUNNING_CONTAINERS[@]})); then
    docker start "${RUNNING_CONTAINERS[@]}" >/dev/null || true
  fi
}
trap 'restart_containers; cleanup' EXIT

if ((${#RUNNING_CONTAINERS[@]})); then
  echo "Pausando containers com dados mutáveis por alguns segundos..."
  docker stop --time 60 "${RUNNING_CONTAINERS[@]}" >/dev/null
fi

echo "Compactando dados persistentes..."
tar \
  --exclude='./backups' \
  --exclude='./postgres/data' \
  -C "${AI_HUB_ROOT}" \
  -czf "${ARCHIVE}" .

restart_containers
RUNNING_CONTAINERS=()

(
  cd "${BACKUP_DIR}"
  sha256sum "$(basename "${ARCHIVE}")" "$(basename "${DB_DUMP}")" > "${CHECKSUMS}"
)

find "${BACKUP_DIR}" -maxdepth 1 -type f \
  \( -name 'ai-hub-*.tar.gz' -o -name 'ai-hub-*.postgres.dump' -o -name 'ai-hub-*.sha256' \) \
  -mtime "+${RETENTION_DAYS}" -delete

echo "Backup concluído:"
echo "  ${ARCHIVE}"
echo "  ${DB_DUMP}"
echo "  ${CHECKSUMS}"
