#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/deploy/env}"
force=false

if [[ "${1:-}" == "--force" ]]; then force=true; elif [[ -n "${1:-}" ]]; then printf 'Uso: %s [--force]\n' "$0" >&2; exit 2; fi
umask 077

if [[ -d "$OUTPUT_DIR" ]] && find "$OUTPUT_DIR" -mindepth 1 -print -quit | grep -q . && [[ "$force" != true ]]; then
  printf 'O diretório %s já contém arquivos. Use --force para substituí-los.\n' "$OUTPUT_DIR" >&2
  exit 1
fi

for required_command in openssl mkdir chmod; do
  command -v "$required_command" >/dev/null 2>&1 || { printf 'Comando obrigatório ausente: %s\n' "$required_command" >&2; exit 1; }
done

read -r -p 'Domínio base (ex.: exemplo.com): ' base_domain
base_domain="${base_domain#https://}"; base_domain="${base_domain#http://}"; base_domain="${base_domain%/}"
[[ "$base_domain" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || { printf 'Domínio inválido: %s\n' "$base_domain" >&2; exit 1; }
read -r -s -p 'OPENAI_API_KEY (Enter para preencher depois): ' openai_api_key; printf '\n'
read -r -s -p 'CLOUDFLARE_TUNNEL_TOKEN (Enter se o túnel já existe): ' cloudflare_token; printf '\n'

random_hex() { openssl rand -hex "$1"; }
random_base64() { openssl rand -base64 "$1" | tr -d '\n'; }

postgres_password="$(random_base64 36)"; redis_password="$(random_base64 36)"
hermes_api_key="$(random_hex 32)"; hermes_dashboard_password="$(random_base64 24)"
hermes_dashboard_secret="$(random_hex 32)"; n8n_encryption_key="$(random_hex 32)"
grafana_password="$(random_base64 24)"
mkdir -p "$OUTPUT_DIR"

cat >"$OUTPUT_DIR/postgres.env" <<EOF
POSTGRES_VERSION=17-alpine
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$postgres_password
EOF
cat >"$OUTPUT_DIR/redis.env" <<EOF
REDIS_VERSION=7-alpine
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
REDIS_PASSWORD=$redis_password
EOF
cat >"$OUTPUT_DIR/hermes.env" <<EOF
HERMES_VERSION=latest
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
OPENAI_API_KEY=$openai_api_key
API_SERVER_KEY=$hermes_api_key
HERMES_DASHBOARD=1
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=$hermes_dashboard_password
HERMES_DASHBOARD_BASIC_AUTH_SECRET=$hermes_dashboard_secret
EOF
cat >"$OUTPUT_DIR/openwebui.env" <<EOF
OPENWEBUI_VERSION=main
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
API_SERVER_KEY=$hermes_api_key
ENABLE_OLLAMA_API=false
EOF
cat >"$OUTPUT_DIR/n8n.env" <<EOF
N8N_VERSION=latest
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
N8N_HOST=n8n.$base_domain
N8N_ENCRYPTION_KEY=$n8n_encryption_key
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=$postgres_password
EOF
cat >"$OUTPUT_DIR/monitoring.env" <<EOF
PROMETHEUS_VERSION=latest
GRAFANA_VERSION=latest
NODE_EXPORTER_VERSION=latest
CADVISOR_VERSION=latest
PROMETHEUS_RETENTION=30d
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$grafana_password
GRAFANA_ROOT_URL=https://grafana.$base_domain
EOF
cat >"$OUTPUT_DIR/ollama.env" <<'EOF'
OLLAMA_VERSION=latest
TZ=America/Sao_Paulo
AI_HUB_ROOT=/srv/ai-hub
AI_HUB_NETWORK=ai-network
OLLAMA_KEEP_ALIVE=5m
EOF
cat >"$OUTPUT_DIR/cloudflared.env" <<EOF
CLOUDFLARED_VERSION=latest
AI_HUB_NETWORK=ai-network
CLOUDFLARE_TUNNEL_TOKEN=$cloudflare_token
EOF
cat >"$OUTPUT_DIR/DEPLOYMENT-URLS.txt" <<EOF
OpenWebUI: https://chat.$base_domain
Hermes Dashboard: https://hermes.$base_domain
Grafana: https://grafana.$base_domain
n8n: https://n8n.$base_domain
EOF
chmod 600 "$OUTPUT_DIR"/*.env "$OUTPUT_DIR/DEPLOYMENT-URLS.txt"

printf '\nArquivos gerados em %s\n' "$OUTPUT_DIR"
printf 'Permissões definidas como 600. Nenhum segredo foi exibido no terminal.\n'
printf 'Revise os arquivos localmente e faça upload de cada .env na stack correspondente.\n'
