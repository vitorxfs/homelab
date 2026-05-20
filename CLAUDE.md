# Homelab — CLAUDE.md

## Visão geral

Stack de serviços self-hosted gerenciada via Docker Compose. O repositório é commitado e **rodado em um servidor dedicado**, não na máquina de desenvolvimento. Qualquer path de volume, configuração ou referência de arquivo deve ser relativa ao repositório (`./`) ou agnóstica de sistema, nunca usar caminhos absolutos hardcoded como `/home/vitor/...`.

## Arquitetura

```
Internet
   │
   ▼
Cloudflare (DNS + proteção)
   │
   ▼
cloudflared (Cloudflare Tunnel — container Docker, rede "proxy")
   │
   ├──► heimdall:80
   ├──► jellyfin:8096
   ├──► prometheus:9090
   ├──► grafana:3000
   ├──► n8n:5678
   └──► host.docker.internal:8123  ──► homeassistant (network_mode: host)

Caddy (reverse proxy — rede "proxy", porta 80/443)
   ├──► heimdall:80
   ├──► jellyfin:8096
   ├──► prometheus:9090
   ├──► grafana:3000
   └──► n8n:5678
   (acesso local via <nome>.local)
```

O Cloudflare Tunnel elimina a necessidade de abrir portas no roteador. O tráfego público chega via `cloudflared`, que roteia cada domínio **diretamente para o serviço** — não passa pelo Caddy. O Caddy existe exclusivamente para acesso local via mDNS (`<nome>.local`).

> Alternativa possível: rotear o cloudflared pelo Caddy para centralizar headers de proxy e configuração de rotas. Não foi adotado por ora.

## Serviços

| Serviço | Imagem | Acesso interno | Descrição |
|---|---|---|---|
| caddy | `caddy:latest` | porta 80/443 | Reverse proxy com TLS interno |
| heimdall | `lscr.io/linuxserver/heimdall` | `heimdall:80` | Dashboard de links |
| jellyfin | `lscr.io/linuxserver/jellyfin` | `jellyfin:8096` | Servidor de mídia |
| homeassistant | `ghcr.io/home-assistant/home-assistant:stable` | `host.docker.internal:8123` | Automação residencial |
| avahi | build local | `network_mode: host` | Publica aliases mDNS na rede local |
| cadvisor | `gcr.io/cadvisor/cadvisor` | `cadvisor:8080` | Métricas por container |
| prometheus | `prom/prometheus` | `prometheus:9090` | Coleta de métricas |
| grafana | `grafana/grafana` | `grafana:3000` | Dashboards de métricas |
| n8n | `docker.n8n.io/n8nio/n8n` | `n8n:5678` | Automação de workflows |
| ai | build local | SSH em `:2222` | Claude Code acessível via SSH |
| cloudflared | `cloudflare/cloudflared` | — | Tunnel Cloudflare para acesso público |

## Redes Docker

- `proxy` — rede compartilhada entre Caddy, serviços web e cloudflared
- `metrics` — rede isolada entre Caddy, cadvisor, prometheus e grafana
- `ai` — rede isolada entre n8n e o container ai

## Acesso

### Acesso local (rede interna)
Os serviços são acessíveis via mDNS em `<nome>.local` (ex: `heimdall.local`, `grafana.local`). O container `avahi` publica esses aliases na rede local usando a interface `wlp1s0`.

O Caddy emite certificados TLS via CA interna. Para acessar sem aviso de segurança, instale o certificado root do Caddy nos dispositivos clientes:
```
caddy_data volume: /pki/authorities/local/root.crt
```

### Acesso externo (internet)
Domínios públicos roteados via Cloudflare Tunnel. O token do tunnel é configurado via variável de ambiente `CLOUDFLARE_TUNNEL_TOKEN` no `.env`.

Mapeamentos públicos configurados no dashboard do Cloudflare (todos diretos, sem passar pelo Caddy):
- `home.vitorsanches.com` → `host.docker.internal:8123` (Home Assistant)
- demais serviços → `heimdall:80`, `jellyfin:8096`, etc. (containers na rede `proxy`)

## Variáveis de ambiente

Arquivo `.env` na raiz do repositório (ignorado pelo git). Use `.env.example` como base:

```env
CLOUDFLARE_TUNNEL_TOKEN=...
ANTHROPIC_API_KEY=...

# URL pública do n8n — necessária para webhooks funcionarem via tunnel
N8N_WEBHOOK_URL=https://n8n.seudominio.com/
```

O n8n monta os endereços de webhook usando `localhost` por padrão. Como o acesso é feito via Cloudflare Tunnel, sem `WEBHOOK_URL` os webhooks gerados apontam para um endereço inacessível externamente. `N8N_PROXY_HOPS=1` instrui o n8n a confiar no header `X-Forwarded-For` enviado pelo tunnel.

## Secrets

Pasta `./secrets/` (ignorada pelo git):

```
secrets/
└── gf_admin_password.txt   # senha do admin do Grafana
```

## Configurações versionadas no repositório

Configs que precisam ser editadas e commitadas ficam em subpastas do repo:

```
homeassistant/config/configuration.yaml   # config do Home Assistant
prometheus.yml                            # scrape targets do Prometheus
grafana/dashboards/                       # dashboards exportados
avahi/services/                           # definições de serviços mDNS
Caddyfile                                 # rotas do reverse proxy
```

## AI — acesso ao Claude Code via SSH

O container `ai` roda um daemon SSH com o Claude Code instalado. Você entra nele via SSH (não via `docker exec`) e executa o `claude` como qualquer CLI.

**Configuração inicial:**

1. Defina `AI_SSH_PASSWORD` no `.env`
2. (opcional) Adicione sua chave pública em `ai/authorized_keys` para usar auth por chave também. Se não for usar, crie o arquivo vazio: `touch ai/authorized_keys`
3. `docker compose up -d ai`
4. Conectar: `ssh -p 2222 claude@<host-do-servidor>` (a senha é a `AI_SSH_PASSWORD`)

**Detalhes:**
- Usuário: `claude` (não-root)
- Porta: `2222` no host → `22` no container
- Autenticação: senha (via `AI_SSH_PASSWORD`) **e/ou** chave pública. Root login desabilitado.
- A senha é aplicada no boot pelo `entrypoint.sh` via `chpasswd`. Se `AI_SSH_PASSWORD` não estiver definida, o container falha ao iniciar.
- `ANTHROPIC_API_KEY` é propagada para o `.profile` do usuário pelo entrypoint, ficando disponível em sessões SSH.
- Volume `ai_home` persiste `/home/claude` (histórico, configs do claude, etc.)

## Home Assistant — configuração de proxy

O Home Assistant usa `network_mode: host` e recebe requisições do cloudflared via `host.docker.internal`. Para que ele aceite requests vindos de proxies reversos sem retornar 400, é necessário declarar `trusted_proxies` em `homeassistant/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
    - 172.16.0.0/12   # range das redes bridge do Docker
    - 192.168.0.0/24  # rede local
```

Sem essa configuração, o HA retorna **400 Bad Request** para qualquer requisição que chegue via Cloudflare/Caddy.

## Métricas (Prometheus + Grafana)

O Prometheus coleta métricas de três fontes:
- `host.docker.internal:9090` — auto-scrape do Prometheus
- `host.docker.internal:9323` — métricas do Docker daemon
- `cadvisor:8080` — métricas por container (CPU, memória, rede, disco)

Para ativar as métricas do Docker daemon, criar `/etc/docker/daemon.json` no servidor:
```json
{
  "metrics-addr": "127.0.0.1:9323"
}
```

## Deploy

```bash
git clone https://github.com/vitorxfs/homelab.git
cd homelab

# Criar secrets
mkdir secrets
echo "senha_aqui" > secrets/gf_admin_password.txt

# Criar .env
cp .env.example .env  # ou criar manualmente com as variáveis acima

docker compose up -d
```

## Observações importantes

- **Evitar caminhos absolutos em volumes** — o repo roda em servidor, não na máquina local. Para configs e dados gerenciados pelo próprio stack, sempre usar `./caminho/relativo:/container/path`.
  - **Exceção:** alguns serviços mapeiam diretórios existentes do host de forma intencional para sincronizar/servir dados que vivem fora do repo. Exemplos atuais:
    - `syncthing` → `/home/vitor/notebooks:/var/syncthing`
    Esses paths absolutos são propositais — não "corrigir" para paths relativos.
- O `homeassistant` usa `network_mode: host`, por isso não está na rede `proxy` do Docker e deve ser acessado via `host.docker.internal`.
- O `avahi` também usa `network_mode: host` e está hardcoded para a interface `wlp1s0` em `avahi/publish.sh` — ajustar se o servidor usar outra interface de rede.
