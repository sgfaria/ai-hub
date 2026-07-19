# n8n

Implante a Stack PostgreSQL antes desta Stack. O n8n usa o banco pela rede
Docker e é publicado somente pelo Cloudflare Tunnel.

Configure a origem do túnel como `http://n8n:5678`. `N8N_ENCRYPTION_KEY` protege
as credenciais gravadas no banco: faça backup dela e nunca a altere depois que
houver credenciais cadastradas.
