# Cloudflare Tunnel

Stack opcional para quem ainda não executa `cloudflared` no servidor. Se o seu
túnel já existe em outra Stack, apenas conecte o container existente à rede
externa `ai-network`; não implante uma segunda instância.

O token deve ser cadastrado como variável da Stack no Portainer e nunca salvo
no Git.
