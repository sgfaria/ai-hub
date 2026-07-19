# Hermes Agent

Stack para Docker Standalone/Portainer baseada na imagem oficial. Todo o
estado interno do Hermes é persistido em `/opt/data`; no host, corresponde a
`/srv/ai-hub/hermes/data` por padrão. A área `/workspace` é exportada
separadamente para facilitar acesso aos projetos criados pelo agente.

## Implantação

1. Execute `scripts/bootstrap-host.sh` no host.
2. No Portainer, crie uma Stack Git usando `hermes/compose.yaml`.
3. Cadastre as variáveis de `.env.example` na Stack, sem confirmar segredos no
   repositório.
4. Faça o deploy e acompanhe os logs de `hermes-agent`.

O gateway expõe somente na rede `ai-network`:

- `8642`: API compatível com OpenAI e endpoint `/health`;
- `9119`: dashboard do Hermes, protegido por autenticação básica.

## Primeiro acesso e modelo

A variável `OPENAI_API_KEY` habilita o provedor OpenAI. Caso a versão instalada
exija a seleção explícita do modelo, abra o console do container no Portainer e
execute:

```bash
hermes setup
```

Escolha OpenAI e `gpt-4o-mini`. O resultado fica persistido em `/opt/data`.

## Cloudflare Tunnel

Se o `cloudflared` estiver ligado à mesma `ai-network`, use como origens:

```text
http://hermes-agent:9119   # dashboard
http://hermes-agent:8642   # API, apenas se realmente necessário externamente
```

Não publique a API sem `API_SERVER_KEY`. Mantenha o dashboard protegido mesmo
atrás do Cloudflare Access.
