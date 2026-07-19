# Deployment no Portainer Standalone

Este procedimento implanta o AI Hub sem publicar portas no host. O acesso web
é feito pelo Cloudflare Tunnel conectado à rede Docker `ai-network`.

## 1. Preparar o host

No servidor Linux, clone o repositório e fixe a revisão que será implantada:

```bash
git clone https://github.com/sgfaria/ai-hub.git
cd ai-hub
git switch main
git pull --ff-only
./scripts/preflight.sh
sudo ./scripts/bootstrap-host.sh
```

O bootstrap cria `/srv/ai-hub`, os diretórios persistentes e a rede bridge
externa `ai-network`. Corrija qualquer erro do preflight antes de prosseguir.

## 2. Gerar os arquivos de ambiente

Em uma máquina confiável com Bash e OpenSSL:

```bash
./scripts/generate-env.sh
```

O script solicita o domínio, a chave da API OpenAI e, opcionalmente, o token do
túnel. Os arquivos ficam em `deploy/env/`, são ignorados pelo Git e recebem
permissão `600`. Não envie essa pasta ao GitHub, por e-mail ou mensageria.

Se o túnel Cloudflare já está em execução, deixe o token em branco e não crie
uma segunda stack `cloudflared`.

## 3. Criar as stacks no Portainer

Em **Stacks > Add stack**, escolha **Git repository** e use:

- Repository URL: `https://github.com/sgfaria/ai-hub.git`
- Repository reference: `refs/heads/main`
- Compose path: o valor da tabela abaixo
- Environment variables: carregue o arquivo `.env` indicado

Ative atualização automática por webhook ou polling somente depois que o
primeiro deployment estiver validado. Para produção, prefira uma tag Git
imutável no campo **Repository reference**.

Implante nesta ordem:

| Ordem | Stack | Compose path | Arquivo de ambiente | Obrigatória |
|---:|---|---|---|---|
| 1 | `ai-postgres` | `postgres/compose.yaml` | `postgres.env` | sim |
| 2 | `ai-redis` | `redis/compose.yaml` | `redis.env` | sim |
| 3 | `ai-hermes` | `hermes/compose.yaml` | `hermes.env` | sim |
| 4 | `ai-openwebui` | `openwebui/compose.yaml` | `openwebui.env` | sim |
| 5 | `ai-ollama` | `ollama/compose.yaml` | `ollama.env` | não |
| 6 | `ai-n8n` | `n8n/compose.yaml` | `n8n.env` | não |
| 7 | `ai-monitoring` | `monitoring/compose.yaml` | `monitoring.env` | sim |
| 8 | `ai-cloudflared` | `cloudflared/compose.yaml` | `cloudflared.env` | somente sem túnel existente |

Após cada stack, confirme em **Containers** que o estado é `running` ou
`healthy`. Se o Portainer solicitar um caminho local para o checkout Git, use
um diretório exclusivo para cada stack sob `/srv/portainer/stacks/ai-hub/`.

## 4. Integrar o túnel Cloudflare existente

O contêiner `cloudflared` existente precisa alcançar os serviços pelo DNS da
rede Docker. Conecte-o uma única vez:

```bash
docker network connect ai-network cloudflared
```

Na configuração do túnel, crie as rotas de aplicação:

| Hostname sugerido | Serviço de origem |
|---|---|
| `chat.seudominio.com` | `http://open-webui:8080` |
| `hermes.seudominio.com` | `http://hermes-agent:9119` |
| `grafana.seudominio.com` | `http://grafana:3000` |
| `n8n.seudominio.com` | `http://n8n:5678` |

Proteja todos os hostnames com Cloudflare Access. Não publique a API Hermes
na porta `8642` externamente, salvo necessidade explícita e política de
autenticação adequada.

## 5. Configurar e validar

Abra o console do contêiner `hermes-agent` no Portainer e execute a configuração
inicial descrita em [`../hermes/README.md`](../hermes/README.md). Em seguida:

```bash
./scripts/post-deploy-check.sh
```

Para também testar o caminho público:

```bash
OPENWEBUI_URL=https://chat.seudominio.com \
HERMES_DASHBOARD_URL=https://hermes.seudominio.com \
GRAFANA_URL=https://grafana.seudominio.com \
N8N_URL=https://n8n.seudominio.com \
./scripts/post-deploy-check.sh
```

Se o Cloudflare Access exigir login, a rota estará protegida, mas o teste sem
credenciais poderá reportar falha. Nesse caso, valide o login pelo navegador.

## 6. Critérios de aceite

- contêineres obrigatórios estão `running` ou `healthy`;
- nenhum serviço possui porta publicada no host;
- OpenWebUI conversa com o Hermes usando a mesma `API_SERVER_KEY`;
- Grafana apresenta as fontes e dashboards provisionados;
- hostnames públicos passam pelo Cloudflare Access;
- um backup inicial foi concluído com `sudo ./scripts/backup.sh`;
- arquivos em `deploy/env/` foram guardados em cofre ou backup criptografado.

Para recuperação e rotina de cópias, consulte
[`backup-restore.md`](backup-restore.md).
