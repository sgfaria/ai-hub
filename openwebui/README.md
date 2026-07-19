# Open WebUI

Interface web conectada à API do Hermes pela rede Docker compartilhada.

Use em `API_SERVER_KEY` exatamente o mesmo valor configurado na Stack Hermes.
Depois do primeiro acesso, o Open WebUI persiste as conexões no banco interno;
alterações posteriores devem ser feitas em **Admin Settings → Connections**.

No Cloudflare Tunnel, configure a origem como:

```text
http://open-webui:8080
```
