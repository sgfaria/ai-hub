# AI Hub

Repositório central para gerenciar e implantar stacks de Inteligência Artificial e ferramentas auxiliares via Docker.

## Stacks Disponíveis

- **`cloudflared/`**: Serviço do Cloudflare Tunnel para expor aplicações locais de forma segura.
- **`hermes/`**: Stack para o agente LLM (`hermes-agent`), com opções de implantação em Docker Swarm e Docker Compose tradicional.
- **`monitoring/`**: Estrutura para coleta de logs e monitoramento (Grafana, Prometheus, Loki).
- **`n8n/`**: Plataforma de automação de fluxo de trabalho.
- **`ollama/`**: Runner de LLM local (inferência de modelos locais).
- **`openwebui/`**: Interface web amigável para chat com LLMs.
- **`postgres/`**: Banco de dados relacional PostgreSQL 17.
- **`redis/`**: Cache em memória Redis 7.

---

## Como Começar

### 1. Criar a Rede Docker Externa
Todas as stacks são configuradas para utilizar uma rede externa compartilhada chamada `ai-network`:

```bash
docker network create ai-network
```

### 2. Configurar e Implantar as Stacks
Navegue até o diretório da stack desejada e siga as instruções específicas.

Para implantar via Portainer (ou diretamente via CLI):
- Certifique-se de que a rede `ai-network` foi criada no ambiente.
- Crie os volumes e arquivos `.env` necessários conforme o `env.example` da stack.
