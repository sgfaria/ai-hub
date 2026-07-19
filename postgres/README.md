# PostgreSQL

Banco interno inicialmente dedicado ao n8n. Não publica a porta 5432 no host;
outros containers na `ai-network` usam o hostname `postgres`.

Use a mesma senha em `POSTGRES_PASSWORD` nesta Stack e em
`DB_POSTGRESDB_PASSWORD` na Stack n8n.
