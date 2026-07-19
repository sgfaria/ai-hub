# Observabilidade

Stack Standalone com:

- Prometheus para métricas;
- Grafana para visualização;
- Node Exporter para métricas do host;
- cAdvisor para métricas dos containers.

## Implantação

1. Execute novamente `scripts/bootstrap-host.sh` para criar os diretórios.
2. No Portainer, crie uma Stack Git usando `monitoring/compose.yaml`.
3. Cadastre as variáveis de `.env.example`.
4. No Cloudflare Tunnel, aponte o hostname do Grafana para
   `http://grafana:3000`.

Prometheus, Node Exporter e cAdvisor não publicam portas no host. O job
`cloudflared` ficará como `DOWN` se o container existente não estiver conectado
à `ai-network` ou não expuser métricas na porta 2000; isso não impede os demais
jobs.

## Segurança

O cAdvisor precisa ler informações do host e do Docker para produzir métricas.
Os mounts são somente leitura, mas essa Stack deve ser administrada como
componente privilegiado de infraestrutura. Não publique cAdvisor, Prometheus ou
Node Exporter na Internet.
