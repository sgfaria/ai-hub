# AI Hub

Infraestrutura modular para agentes e serviços de IA em um homelab, usando
Docker Compose/Portainer em modo **Standalone**. O projeto não requer Swarm.

## Princípios

- uma stack por diretório;
- rede bridge externa compartilhada `ai-network`;
- dados persistentes em bind mounts sob `/srv/ai-hub`;
- segredos fora do Git, fornecidos por `.env` ou pela interface do Portainer;
- nenhuma porta publicada por padrão: o Cloudflare Tunnel acessa os serviços
  diretamente pela rede Docker;
- imagens versionadas por variável para permitir atualização controlada.

## Componentes

| Diretório | Serviço | Estado |
|---|---|---|
| `hermes/` | Hermes Agent e API compatível com OpenAI | utilizável |
| `openwebui/` | Interface web conectada ao Hermes | utilizável |
| `ollama/` | Inferência local opcional | base |
| `postgres/` | Banco compartilhado | base |
| `redis/` | Cache compartilhado | base |
| `n8n/` | Automação | base |
| `cloudflared/` | Integração com túnel existente | base |
| `monitoring/` | Prometheus, Grafana, Node Exporter e cAdvisor | utilizável |
| `scripts/` | Bootstrap, backup e restauração | utilizável |

## Início rápido

No host Docker:

```bash
sudo ./scripts/bootstrap-host.sh
```

Depois, no Portainer, crie uma Stack a partir do repositório Git e use o
arquivo `hermes/compose.yaml`. Cadastre as variáveis de `hermes/.env.example`
na tela da Stack. Faça o mesmo com `openwebui/compose.yaml`.

Antes do primeiro uso, configure o provedor do Hermes conforme o guia em
[`hermes/README.md`](hermes/README.md). A chave `API_SERVER_KEY` deve ser a
mesma nas stacks Hermes e Open WebUI.

## Segurança

Nunca confirme arquivos `.env`, tokens, senhas ou backups no Git. Os bancos
não publicam portas no host. Para acesso externo, crie hostnames no Cloudflare
Tunnel apontando para os nomes Docker, por exemplo `http://open-webui:8080` e
`http://hermes-agent:9119`.

## Operação

- [Backup e restauração](docs/backup-restore.md)
- [Observabilidade](monitoring/README.md)
