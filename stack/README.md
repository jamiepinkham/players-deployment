# BMPL Stack - Technical Reference

Complete technical documentation for the `bmpl` Portainer stack on fenway.

This stack contains all BMPL infrastructure: Production Rails, QA Rails, Ghost blog, and supporting services (Caddy, Cloudflare Tunnel, databases, Redis, background workers).

## Services (14 Total)

### Infrastructure
- **caddy** - Reverse proxy (Caddyfile embedded via Docker config)
- **cloudflared** - Cloudflare Tunnel for secure access

### Production - Players Rails App
- **players-web** - Rails application (port 3000)
- **players-db** - PostgreSQL database
- **players-redis** - Redis cache/session store
- **players-sidekiq** - Background job processor
- **players-scheduler** - Cron job scheduler (supercronic)

### QA - Players Rails App (Testing)
- **players-web-qa** - Rails QA instance (port 3000)
- **players-db-qa** - PostgreSQL QA database
- **players-redis-qa** - Redis QA instance
- **players-sidekiq-qa** - QA background jobs
- **players-scheduler-qa** - QA cron scheduler

### Ghost Blog
- **ghost** - Ghost blog (port 2368)
- **ghost-db** - MySQL database

## Deployment via Portainer UI

**Prerequisites:**
- `.env.fenway` with all credentials (see `.env.template`)
- `docker-compose.consolidated.yml` (includes embedded Caddyfile)

**✨ Self-Contained:** The Caddyfile is embedded in the compose file using Docker configs—no external file uploads needed!

**Steps:**

1. Open Portainer (http://fenway:9000)
2. Stacks → **+ Add stack**
3. Name: `bmpl-consolidated`
4. **Web editor**: Copy-paste entire `docker-compose.consolidated.yml`
5. **Environment variables** → Advanced mode → Paste entire `.env.fenway`
6. **Deploy the stack**

See Portainer UI for deployment (Stacks → bmpl → Editor).

## Environment Variables

Single `.env` file configures all services:

```bash
# Infrastructure
CLOUDFLARE_TUNNEL_TOKEN=...

# Production Rails
SECRET_KEY_BASE=...
MAILGUN_SMTP_USERNAME=...
MAILGUN_SMTP_PASSWORD=...

# QA Rails (optional, uses production values if empty)
GIT_REF=jp-consolidated-fa-improvements
SECRET_KEY_BASE_QA=

# Ghost
GHOST_DB_PASSWORD=...
GHOST_MAIL_PASSWORD=...
```

See `.env.template` for full list.

## Networks

Three isolated networks:

- **web** - Caddy, Cloudflared, and web services (production, QA, Ghost)
- **default** (players_default) - Production Rails stack + Ghost
- **qa** (players_qa) - QA Rails stack

## Volumes

Clean, logical volume names (migrated from old messy names):

- `players_db_data` - Production PostgreSQL (was: `bmpl-apps_players-db-data`)
- `players_db_data_qa` - QA PostgreSQL (was: `bmpl-apps-qa_players-db-data-qa`)
- `ghost_db_data` - Ghost MySQL (was: `ghost_ghost_mysql`)
- `ghost_content` - Ghost themes/content (was: `ghost_ghost_content`)
- `caddy_data` - SSL certificates (new)
- `caddy_config` - Caddy configuration cache (new)

## Updating Services

**Pull latest Rails image and restart:**
```bash
ssh ortiz@fenway
docker pull ghcr.io/jamiepinkham/players:main
docker restart players-web players-sidekiq players-scheduler
```

**Update QA to different branch:**
```bash
# In Portainer: Edit stack → Change GIT_REF env var → Update
# Example: GIT_REF=jp-consolidated-fa-improvements
```

**Update Ghost:**
```bash
docker pull ghost:latest
docker restart ghost
```

## Viewing Logs

**Via Portainer:**
- Stacks → bmpl-consolidated → Click service name → Logs

**Via SSH:**
```bash
ssh ortiz@fenway
docker logs -f ghost
docker logs -f players-web
docker logs -f players-sidekiq
```

## URLs

- Production: https://players.billymartinplayersleague.com
- QA: https://qa.billymartinplayersleague.com
- Ghost Blog: https://billymartinplayersleague.com
- Ghost Admin: https://billymartinplayersleague.com/ghost

## Troubleshooting

See `docs/DEPLOYMENT.md` for troubleshooting procedures.

**Common issues:**
- Duplicate containers → Check `docker ps -a | grep ghost`
- Database connection errors → Check health with `docker ps`
- Ghost 403 errors → Ensure only ONE ghost container running
