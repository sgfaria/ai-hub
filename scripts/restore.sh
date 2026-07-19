#!/usr/bin/env bash
set -Eeuo pipefail

AI_HUB_ROOT="${AI_HUB_ROOT:-/srv/ai-hub}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-n8n}"
POSTGRES_USER="${POSTGRES_USER:-n8n}"

usage() {
  echo "Uso: sudo $0 --archive ARQUIVO.tar.gz --database ARQUIVO.postgres.dump --confirm" >&2
}

ARCHIVE=""
DB_DUMP=""
CONFIRM="false"

while (($#)); do
  case "$1" in
    --archive) ARCHIVE="${2:-}"; shift 2 ;;
    --database) DB_DUMP="${2:-}"; shift 2 ;;
    --confirm) CONFIRM="true"; shift ;;
    *) usage; exit 2 ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root." >&2
  exit 1
fi

if [[ "${CONFIRM}" != "true" || ! -f "${ARCHIVE}" || ! -f "${DB_DUMP}" ]]; then
  usage
  exit 2
fi

case "$(realpath -m "${AI_HUB_ROOT}")" in
  /|/home|/root|/srv) echo "AI_HUB_ROOT inseguro: ${AI_HUB_ROOT}" >&2; exit 1 ;;
esac

if [[ ! -f "${AI_HUB_ROOT}/.ai-hub-root" ]]; then
  echo "Diretório não inicializado pelo AI Hub: ${AI_HUB_ROOT}" >&2
  echo "Execute scripts/bootstrap-host.sh antes da restauração." >&2
  exit 1
fi

echo "ATENÇÃO: os dados atuais em ${AI_HUB_ROOT} serão substituídos."
read -r -p "Digite RESTAURAR para continuar: " answer
if [[ "${answer}" != "RESTAURAR" ]]; then
  echo "Restauração cancelada."
  exit 1
fi

mapfile -t RUNNING_CONTAINERS < <(
  for name in hermes-agent open-webui n8n redis grafana prometheus; do
    if [[ "$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || true)" == "true" ]]; then
      printf '%s\n' "${name}"
    fi
  done
)

if ((${#RUNNING_CONTAINERS[@]})); then
  docker stop --time 60 "${RUNNING_CONTAINERS[@]}" >/dev/null
fi

install -d -m 0750 "${AI_HUB_ROOT}"
# O PostgreSQL é restaurado logicamente logo abaixo; seus arquivos físicos
# permanecem intactos enquanto o banco está em execução.
find "${AI_HUB_ROOT}" -mindepth 1 -maxdepth 1 \
  ! -name backups ! -name postgres -exec rm -rf -- {} +
tar -C "${AI_HUB_ROOT}" -xzf "${ARCHIVE}"

docker start "${POSTGRES_CONTAINER}" >/dev/null
until docker exec "${POSTGRES_CONTAINER}" pg_isready -U "${POSTGRES_USER}" -d postgres >/dev/null 2>&1; do
  sleep 2
done

docker exec "${POSTGRES_CONTAINER}" dropdb -U "${POSTGRES_USER}" --if-exists "${POSTGRES_DB}"
docker exec "${POSTGRES_CONTAINER}" createdb -U "${POSTGRES_USER}" "${POSTGRES_DB}"
docker exec -i "${POSTGRES_CONTAINER}" pg_restore \
  -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --clean --if-exists < "${DB_DUMP}"

if ((${#RUNNING_CONTAINERS[@]})); then
  docker start "${RUNNING_CONTAINERS[@]}" >/dev/null
fi

echo "Restauração concluída. Verifique os logs e healthchecks das Stacks."
