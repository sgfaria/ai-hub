#!/usr/bin/env bash
set -Eeuo pipefail

AI_HUB_ROOT="${AI_HUB_ROOT:-/srv/ai-hub}"
AI_HUB_NETWORK="${AI_HUB_NETWORK:-ai-network}"
MIN_DISK_GB="${MIN_DISK_GB:-20}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-4}"
errors=0
warnings=0

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[ERRO] %s\n' "$*"; errors=$((errors + 1)); }

printf 'Preflight do AI Hub\nRaiz de dados: %s\nRede Docker: %s\n\n' "$AI_HUB_ROOT" "$AI_HUB_NETWORK"

if [[ "$(uname -s)" == "Linux" ]]; then ok 'Sistema Linux detectado'; else fail 'A implantação deve ser executada em um host Linux'; fi
case "$(uname -m)" in
  x86_64|aarch64|arm64) ok "Arquitetura suportada: $(uname -m)" ;;
  *) warn "Arquitetura não validada: $(uname -m)" ;;
esac
if [[ "$EUID" -eq 0 ]]; then ok 'Execução com privilégios administrativos'; else warn 'Execute o bootstrap com sudo; o preflight pode continuar sem root'; fi

for command_name in docker openssl curl tar sha256sum; do
  if command -v "$command_name" >/dev/null 2>&1; then ok "Comando disponível: $command_name"; else fail "Comando ausente: $command_name"; fi
done

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then ok 'Docker Engine acessível'; else fail 'Docker Engine não está acessível para este usuário'; fi
  if docker compose version >/dev/null 2>&1; then ok 'Docker Compose v2 disponível'; else fail 'Docker Compose v2 não está disponível'; fi
  if docker network inspect "$AI_HUB_NETWORK" >/dev/null 2>&1; then ok "Rede Docker existente: $AI_HUB_NETWORK"; else warn "Rede $AI_HUB_NETWORK ainda não existe; o bootstrap irá criá-la"; fi

  container_names=(postgres redis hermes-agent open-webui ollama n8n prometheus grafana node-exporter cadvisor cloudflared)
  for container_name in "${container_names[@]}"; do
    if docker container inspect "$container_name" >/dev/null 2>&1; then warn "Já existe um contêiner chamado $container_name; confirme se pertence ao AI Hub"; fi
  done
fi

disk_available_gb="$(df -Pk "$(dirname "$AI_HUB_ROOT")" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}' || true)"
[[ -n "$disk_available_gb" ]] || disk_available_gb="$(df -Pk / | awk 'NR==2 {printf "%d", $4/1024/1024}')"
if (( disk_available_gb >= MIN_DISK_GB )); then ok "Espaço livre: ${disk_available_gb} GB"; else warn "Espaço livre de ${disk_available_gb} GB; recomendado: ${MIN_DISK_GB} GB ou mais"; fi

memory_gb="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
if (( memory_gb >= MIN_MEMORY_GB )); then ok "Memória instalada: ${memory_gb} GB"; else warn "Memória instalada de ${memory_gb} GB; recomendado: ${MIN_MEMORY_GB} GB ou mais"; fi

printf '\nResultado: %d erro(s), %d aviso(s).\n' "$errors" "$warnings"
(( errors == 0 )) || exit 1
printf 'Host apto para prosseguir. Revise os avisos antes do deployment.\n'
