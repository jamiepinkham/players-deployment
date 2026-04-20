# Deployment Guide for BMPL Stack on Fenway

## Environment Variables Required

When deploying this stack in Portainer, set these environment variables:

```bash
POSTGRES_PASSWORD=postgres
SECRET_KEY_BASE=<generate with: openssl rand -hex 64>
MAILGUN_SMTP_USERNAME=postmaster@mail.billymartinplayersleague.com
MAILGUN_SMTP_PASSWORD=<from Mailgun dashboard>
GHOST_DB_PASSWORD=<generate with: openssl rand -hex 32>
```

### Notes:
- `POSTGRES_PASSWORD` is set to a dummy value since PostgreSQL uses trust auth
- `SECRET_KEY_BASE` must be a secure 128-character hex string
- Mailgun credentials are from your Mailgun account
- `GHOST_DB_PASSWORD` should be a secure random password

## Deployment Steps in Portainer

1. Access Portainer at `http://fenway:9000`
2. Go to Stacks → Add Stack
3. Name the stack (e.g., "bmpl-apps")
4. Paste the docker-compose.yml contents
5. Add the environment variables listed above
6. Deploy the stack

## Troubleshooting

### Players containers restarting
- Check that all environment variables are set
- Verify `POSTGRES_PASSWORD` is not empty
- Check logs: `docker logs players-web` or `docker logs players-scheduler`

### Ghost containers restarting
- Verify `GHOST_DB_PASSWORD` matches between ghost and ghost-db
- Check ghost-db is healthy: `docker ps --filter name=ghost-db`

### Scheduler not running
- The scheduler uses `supercronic /app/config/crontab`
- Check the crontab runs at midnight Eastern: `/app/config/crontab`
- Logs: `docker logs players-scheduler`

## Container Architecture

- **players-web**: Rails app serving on port 3000
- **players-db**: PostgreSQL 16 database
- **players-scheduler**: Cron jobs using supercronic
- **ghost**: Ghost blog CMS
- **ghost-db**: MySQL 8.0 database for Ghost

## Networks

- `players_default`: Internal network for stack communication
- `web`: External network (must exist) for Caddy reverse proxy
