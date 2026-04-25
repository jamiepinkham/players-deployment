# BMPL Infrastructure Documentation

Complete documentation of how the Billy Martin Players League stack works on fenway (Hetzner VPS).

## Purpose

This repo documents the entire BMPL infrastructure holistically:
- How all services connect and communicate
- Cloudflare configuration and tunnel setup
- Network architecture and routing
- Operational procedures

The stack runs in Portainer on fenway. This repo stays local as reference documentation.

## Architecture Overview

### The Stack

**Portainer stack:** `bmpl` (14 containers)

```
Internet
  ↓
Cloudflare (DNS, SSL, DDoS protection)
  ↓
Cloudflare Tunnel (encrypted connection to fenway)
  ↓
cloudflared container
  ↓
Caddy reverse proxy (routes by hostname)
  ├→ players.billymartinplayersleague.com → players-web:3000
  ├→ qa.billymartinplayersleague.com → players-web-qa:3000
  └→ billymartinplayersleague.com → ghost:2368
```

### Services

**Infrastructure:**
- caddy - Reverse proxy
- cloudflared - Cloudflare Tunnel endpoint

**Production Rails:**
- players-web - Application server
- players-db - PostgreSQL database
- players-redis - Cache/sessions
- players-sidekiq - Background jobs
- players-scheduler - Cron jobs (supercronic)

**QA Rails:**
- players-web-qa - QA application (deploys branch via GIT_REF)
- players-db-qa - QA PostgreSQL
- players-redis-qa - QA Redis
- players-sidekiq-qa - QA background jobs
- players-scheduler-qa - QA cron jobs

**Ghost Blog:**
- ghost - Ghost CMS
- ghost-db - MySQL database

### External Dependencies

**shared-network stack:** Creates the `web` bridge network that all public services connect to. Keep this stack - it's required for networking.

**Cloudflare Tunnel:** All three domains point to the same tunnel, which routes to Caddy. See `docs/CLOUDFLARE.md`.

## Key Files

**Stack definition:** `stack/docker-compose.consolidated.yml`
- Complete configuration for all 14 services
- Caddyfile embedded as Docker config
- Networks and volume definitions

**Secrets:** `stack/.env.fenway`
- Environment variables for all services
- Cloudflare tunnel token
- Database passwords, Rails secrets, Mailgun credentials
- Gitignored, stored in 1Password vault

**Template:** `stack/.env.template`
- Shows structure of required environment variables
- Safe to commit (uses placeholders)

## How It Works

### Cloudflare Tunnel

**DNS:** All three domains CNAME to `UUID.cfargotunnel.com`

**Tunnel configuration (Cloudflare Zero Trust):**
- players.billymartinplayersleague.com → http://caddy:80
- qa.billymartinplayersleague.com → http://caddy:80
- billymartinplayersleague.com → http://caddy:80

The tunnel connects Cloudflare's edge to the cloudflared container on fenway. No public IP needed.

**See:** `docs/CLOUDFLARE.md` for tunnel setup and management.

### Caddy Routing

Caddy inspects the `Host` header and routes to the appropriate backend:

```
Host: players.billymartinplayersleague.com → players-web:3000
Host: qa.billymartinplayersleague.com → players-web-qa:3000
Host: billymartinplayersleague.com → ghost:2368
```

Caddyfile is embedded in the docker-compose as a Docker config (no external file needed).

### Networks

**web** (external) - Shared network created by shared-network stack
- Connects: portainer, caddy, cloudflared, players-web, players-web-qa, ghost

**players_default** - Production Rails + Ghost internal network
- Connects: players-web, players-db, players-redis, players-sidekiq, players-scheduler, ghost, ghost-db

**players_qa** - QA Rails internal network
- Connects: players-web-qa, players-db-qa, players-redis-qa, players-sidekiq-qa, players-scheduler-qa

### Volumes

| Volume | Size | Purpose |
|--------|------|---------|
| players_db_data | ~70MB | Production PostgreSQL data |
| players_db_data_qa | ~75MB | QA PostgreSQL data |
| ghost_db_data | ~240MB | Ghost MySQL data |
| ghost_content | ~1GB | Ghost themes/uploads |
| caddy_data | Small | SSL certificates |
| caddy_config | Small | Caddy cache |

## Common Operations

### View Logs

Portainer → bmpl → Click service → Logs

Or via SSH:
```bash
docker logs -f players-web
docker logs -f ghost
```

### Restart Service

Portainer → bmpl → Click service → Restart

Or:
```bash
docker restart players-web
```

### Update Stack Configuration

1. Edit `stack/docker-compose.consolidated.yml` locally
2. Portainer → bmpl → Editor
3. Copy-paste updated content
4. Update the stack

### Update Environment Variables

Portainer → bmpl → Editor → Environment variables

Common changes:
- `GIT_REF` - Change QA branch
- `CLOUDFLARE_TUNNEL_TOKEN` - Update tunnel token

### Update Rails Application

When new image pushed to GitHub:
```bash
docker pull ghcr.io/jamiepinkham/players:main
docker restart players-web players-sidekiq players-scheduler
```

### Backup Databases

```bash
# Production
docker exec players-db pg_dumpall -U postgres > /tmp/players_$(date +%Y%m%d).sql

# Ghost
docker exec ghost-db mysqldump -u root -pdjshklxzvbcsajlk ghost > /tmp/ghost_$(date +%Y%m%d).sql
```

### Sync Production Data to QA

Copy `scripts/sync-prod-to-qa.sh` to fenway and run it there.
See `docs/MANUAL_QA_SYNC.md` for details.

## Documentation

**Understanding the stack:**
- `README.md` (this file) - Architecture overview
- `stack/README.md` - Technical details of all services
- `stack/docker-compose.consolidated.yml` - The actual stack definition

**Cloudflare:**
- `docs/CLOUDFLARE.md` - Tunnel setup, DNS, SSL configuration

**Operations:**
- `docs/DEPLOYMENT.md` - Day-to-day operations guide
- `docs/ROLLBACK.md` - Rollback procedures
- `docs/MANUAL_QA_SYNC.md` - Sync prod data to QA

## URLs

- **Production:** https://players.billymartinplayersleague.com
- **QA:** https://qa.billymartinplayersleague.com
- **Ghost:** https://billymartinplayersleague.com
- **Ghost Admin:** https://billymartinplayersleague.com/ghost
- **Portainer:** http://fenway:9000 (via SSH tunnel)

## Environment Variables

All secrets in `stack/.env.fenway`:

**Cloudflare:**
- `CLOUDFLARE_TUNNEL_TOKEN` - Get from Zero Trust dashboard

**Production Rails:**
- `POSTGRES_PASSWORD` - Set to `notused` (trust auth, but Rails validates)
- `SECRET_KEY_BASE` - Rails secret
- `MAILGUN_SMTP_USERNAME`, `MAILGUN_SMTP_PASSWORD` - Email sending

**QA Rails:**
- `GIT_REF` - Branch/tag to deploy (e.g., `main`, `feature-branch`)
- `POSTGRES_PASSWORD_QA` - Set to `notused`
- `SECRET_KEY_BASE_QA` - Empty uses production value

**Ghost:**
- `GHOST_DB_PASSWORD` - MySQL password
- `GHOST_MAIL_USER`, `GHOST_MAIL_PASSWORD`, `GHOST_MAIL_FROM` - Email config

## Troubleshooting

**Container not starting:**
```bash
docker logs <container> --tail 50
```

**Ghost login issues:**
```bash
# Clear rate limiting
docker exec ghost-db mysql -u ghost -pdjshklxzvbcsajlk ghost -e "TRUNCATE TABLE brute;"

# Ensure only one Ghost running
docker ps -a | grep ghost
```

**Tunnel down:**
```bash
docker logs cloudflared
docker restart cloudflared
```

See `docs/DEPLOYMENT.md` for detailed troubleshooting.
