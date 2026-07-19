#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Comando obrigatório não encontrado: $1" >&2
    exit 1
  fi
}

require_command docker
require_command shellcheck
require_command yamllint

echo "==> Validando scripts Bash"
mapfile -d '' SHELL_FILES < <(find scripts -type f -name '*.sh' -print0 | sort -z)
if ((${#SHELL_FILES[@]} == 0)); then
  echo "Nenhum script Bash encontrado." >&2
  exit 1
fi
bash -n "${SHELL_FILES[@]}"
shellcheck -x "${SHELL_FILES[@]}"

echo "==> Validando arquivos YAML"
yamllint --config-file .yamllint.yml .

echo "==> Validando Docker Compose"
export API_SERVER_KEY="ci-api-server-key"
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME="ci-admin"
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="ci-dashboard-password"
export HERMES_DASHBOARD_BASIC_AUTH_SECRET="ci-dashboard-session-secret"
export OPENAI_API_KEY="sk-ci-placeholder"
export CLOUDFLARE_TUNNEL_TOKEN="ci-cloudflare-token"
export POSTGRES_PASSWORD="ci-postgres-password"
export REDIS_PASSWORD="ci-redis-password"
export N8N_HOST="n8n.example.invalid"
export N8N_ENCRYPTION_KEY="ci-n8n-encryption-key"
export DB_POSTGRESDB_PASSWORD="ci-postgres-password"
export GRAFANA_ADMIN_PASSWORD="ci-grafana-password"
export GRAFANA_ROOT_URL="https://grafana.example.invalid"

mapfile -d '' COMPOSE_FILES < <(find . -type f -name 'compose.yaml' -print0 | sort -z)
if ((${#COMPOSE_FILES[@]} == 0)); then
  echo "Nenhum compose.yaml encontrado." >&2
  exit 1
fi

for compose_file in "${COMPOSE_FILES[@]}"; do
  echo "  - ${compose_file#./}"
  docker compose -f "${compose_file}" config --quiet
done

echo "Validação concluída: ${#SHELL_FILES[@]} scripts e ${#COMPOSE_FILES[@]} Stacks."
