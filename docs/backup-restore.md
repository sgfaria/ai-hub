# Backup e restauração

Os scripts cobrem os bind mounts sob `/srv/ai-hub` e produzem um dump lógico
consistente do PostgreSQL. A pasta `backups` e os arquivos físicos do PostgreSQL
não são incluídos no arquivo compactado.

Execute `scripts/bootstrap-host.sh` pelo menos uma vez. Ele cria o marcador de
segurança usado pelos scripts para impedir operações em um diretório incorreto.

## Backup manual

```bash
sudo ./scripts/backup.sh
```

São gerados três arquivos com o mesmo timestamp:

- `ai-hub-*.tar.gz`: dados persistentes das aplicações;
- `ai-hub-*.postgres.dump`: dump do PostgreSQL;
- `ai-hub-*.sha256`: checksums dos dois arquivos.

Antes de transferir ou restaurar, valide a integridade:

```bash
cd /srv/ai-hub/backups
sha256sum -c ai-hub-TIMESTAMP.sha256
```

Os containers com dados mutáveis são pausados brevemente durante a compactação.
O PostgreSQL continua disponível e é copiado por `pg_dump`.

## Agendamento

Exemplo de cron diário às 03:15:

```cron
15 3 * * * /srv/ai-hub-repo/scripts/backup.sh >> /var/log/ai-hub-backup.log 2>&1
```

Por padrão, arquivos com mais de 14 dias são removidos. Ajuste com
`RETENTION_DAYS`.

## Restauração

Teste primeiro em outro host. A restauração é destrutiva e exige duas
confirmações:

```bash
sudo ./scripts/restore.sh \
  --archive /srv/ai-hub/backups/ai-hub-TIMESTAMP.tar.gz \
  --database /srv/ai-hub/backups/ai-hub-TIMESTAMP.postgres.dump \
  --confirm
```

Digite `RESTAURAR` quando solicitado. Depois confira os logs, as permissões dos
bind mounts e os healthchecks no Portainer.
