# Fenway Portainer Stack

This is the unified Portainer stack for fenway, containing both the Players fantasy baseball app and the Ghost blog.

## Services

### Players App
- **players-web** - Rails application server (port 3000)
- **players-db** - PostgreSQL database for players app
- **players-scheduler** - Background job scheduler (whenever/cron)

### Ghost Blog
- **ghost** - Ghost blog application (port 2368)
- **ghost-db** - PostgreSQL database for ghost

## Architecture

All services run on a single Docker network (`fenway`) and share centralized credentials:

- **shared.env** - Database credentials and Rails secrets (players services)
- **mailgun.env** - Mailgun API credentials (shared by players-web, players-scheduler, and ghost)
- **players.env** - Players-specific configuration
- **ghost.env** - Ghost-specific configuration

## Deployment to Portainer

### Option 1: Deploy via Portainer UI

1. Log into Portainer at http://fenway:9000
2. Go to Stacks → Add Stack
3. Name: `bmpl-apps`
4. Build method: Repository (or Upload)
5. Repository URL: `https://github.com/jamiepinkham/players-deployment`
6. Repository reference: `main`
7. Compose path: `stack/docker-compose.yml`
8. Environment variables: Add from env templates
9. Deploy the stack

### Option 2: Deploy via Portainer API

```bash
./deploy-portainer-stack.sh
```

### Option 3: Manual Docker Compose

```bash
cd /Users/jp/dev/players-deployment/stack
docker-compose up -d
```

## Environment Setup

Before deploying, create the environment file:

```bash
cd stack
cp .env.template .env

# Edit with actual credentials
vim .env
```

Required variables:
- `POSTGRES_PASSWORD` - PostgreSQL password
- `SECRET_KEY_BASE` - Rails secret (generate with `rails secret`)
- `MAILGUN_SMTP_USERNAME` - Mailgun SMTP username
- `MAILGUN_SMTP_PASSWORD` - Mailgun API key
- `GHOST_DB_PASSWORD` - MySQL password for Ghost

## Volumes

Persistent data is stored in Docker volumes:

- `players-db-data` - Players PostgreSQL database
- `players-storage` - Rails Active Storage files
- `players-uploads` - Rails uploaded files
- `ghost-db-data` - Ghost PostgreSQL database
- `ghost-content` - Ghost blog content and themes

## Networking

All services communicate via the `fenway` bridge network. External access is provided through Caddy reverse proxy:

- Players app: https://players.example.com → players-web:3000
- Ghost blog: https://blog.example.com → ghost:2368

## Logs

View logs for any service:

```bash
docker logs -f players-web
docker logs -f ghost
docker logs -f players-scheduler
```

## Backup

See `../docs/BACKUP.md` for backup procedures.

## Rollback

See `../docs/ROLLBACK.md` for rollback procedures.
