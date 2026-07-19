#!/usr/bin/env bash
set -Eeuo pipefail

AI_HUB_NETWORK="${AI_HUB_NETWORK:-ai-network}"
CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:8.12.1}"
errors=0
warnings=0

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[ERRO] %s\n' "$*"; errors=$((errors + 1)); }

command -v docker >/dev/null 2>&1 || { printf '[ERRO] Docker não encontrado.\n' >&2; exit 1; }
docker info >/dev/null 2>&1 || { printf '[ERRO] Docker Engine inacessível.\n' >&2; exit 1; }

if docker network inspect "$AI_HUB_NETWORK" >/dev/null 2>&1; then ok "Rede disponível: $AI_HUB_NETWORK"; else fail "Rede ausente: $AI_HUB_NETWORK"; fi
required_containers=(postgres redis hermes-agent open-webui prometheus grafana node-exporter cadvisor)
optional_containers=(ollama n8n cloudflared)

check_container() {
  local container_name="$1" required="$2" status
  if ! docker container inspect "$container_name" >/dev/null 2>&1; then
    if [[ "$required" == true ]]; then fail "Contêiner ausente: $container_name"; else warn "Contêiner opcional ausente: $container_name"; fi
    return
  fi
  status="$(docker inspect --format '{{.State.Status}}' "$container_name")"
  if [[ "$status" == "running" ]]; then ok "Contêiner em execução: $container_name"; elif [[ "$required" == true ]]; then fail "$container_name está $status"; else warn "$container_name está $status"; fi

  if [[ "$(docker inspect --format "{{if index .NetworkSettings.Networks \"$AI_HUB_NETWORK\"}}yes{{else}}no{{end}}" "$container_name")" != "yes" ]]; then
    if [[ "$container_name" == "cloudflared" ]]; then warn "cloudflared não está conectado à rede $AI_HUB_NETWORK"; else fail "$container_name não está conectado à rede $AI_HUB_NETWORK"; fi
  fi
  docker port "$container_name" 2>/dev/null | grep -q . && warn "$container_name possui porta publicada no host"
}

for container_name in "${required_containers[@]}"; do check_container "$container_name" true; done
for container_name in "${optional_containers[@]}"; do check_container "$container_name" false; done

http_check() {
  local name="$1" url="$2"
  if docker run --rm --network "$AI_HUB_NETWORK" "$CURL_IMAGE" --fail --silent --show-error --max-time 15 "$url" >/dev/null; then ok "HTTP interno: $name"; else fail "Falha HTTP interna: $name ($url)"; fi
}

if (( errors == 0 )); then
  http_check 'Hermes API' 'http://hermes-agent:8642/health'
  http_check 'OpenWebUI' 'http://open-webui:8080/health'
  http_check 'Prometheus' 'http://prometheus:9090/-/ready'
  http_check 'Grafana' 'http://grafana:3000/api/health'
else
  warn 'Testes HTTP internos foram ignorados devido a erros de infraestrutura'
fi

external_urls=("${OPENWEBUI_URL:-}" "${HERMES_DASHBOARD_URL:-}" "${GRAFANA_URL:-}" "${N8N_URL:-}")
for external_url in "${external_urls[@]}"; do
  [[ -z "$external_url" ]] && continue
  if curl --fail --silent --show-error --max-time 20 "$external_url" >/dev/null; then ok "URL externa acessível: $external_url"; else fail "URL externa inacessível: $external_url"; fi
done

printf '\nResultado: %d erro(s), %d aviso(s).\n' "$errors" "$warnings"
(( errors == 0 )) || exit 1
printf 'Verificação pós-deployment concluída.\n'
