# Deployment Guide

This guide covers deploying the unified fenway stack.

## Prerequisites

- Docker and Docker Compose installed on fenway
- Access to the server (SSH as ortiz@fenway)
- GitHub access to pull the players image
- Environment variable values (passwords, keys, etc.)

## Initial Setup

### 1. Clone the Repository

```bash
ssh ortiz@fenway
cd ~
git clone https://github.com/jamiepinkham/players-deployment.git
cd players-deployment/stack
```

### 2. Create Environment File

```bash
cp .env.template .env
vim .env
```

Fill in all the `CHANGE_ME` values:
- `POSTGRES_PASSWORD` - PostgreSQL password for players database
- `SECRET_KEY_BASE` - Rails secret key base (generate with `rails secret`)
- `MAILGUN_SMTP_USERNAME` - Mailgun SMTP username
- `MAILGUN_SMTP_PASSWORD` - Mailgun SMTP password
- `GHOST_DB_PASSWORD` - MySQL password for Ghost database

### 3. Create External Web Network

This network is shared between the stack and Caddy:

```bash
docker network create web
```

### 4. Deploy the Stack

```bash
docker-compose up -d
```

### 5. Verify Deployment

```bash
# Check all containers are running
docker ps

# Check logs
docker-compose logs -f players-web
docker-compose logs -f ghost

# Check health
docker inspect players-db-1 | grep -A5 Health
docker inspect ghost-db | grep -A5 Health
```

### 6. Initialize Database (First Time Only)

```bash
# Players database
docker exec -it players-players-1 bundle exec rails db:create db:migrate

# Ghost will initialize automatically on first run
```

## Updating the Stack

### Update Players App

```bash
cd ~/players-deployment/stack
docker-compose pull players-web players-scheduler
docker-compose up -d players-web players-scheduler
```

### Update Ghost

```bash
cd ~/players-deployment/stack
docker-compose pull ghost
docker-compose up -d ghost
```

### Update Entire Stack

```bash
cd ~/players-deployment/stack
docker-compose pull
docker-compose up -d
```

## Accessing Services

With Caddy configured:
- Players: https://billymartinplayersleague.com
- Ghost: (configure in Caddyfile if needed)

Direct access (via SSH tunnel):
- Players: http://fenway:3000
- Ghost: http://fenway:2368 (not exposed, use docker network)

## Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f players-web
docker-compose logs -f ghost
docker-compose logs -f players-scheduler

# Last 100 lines
docker-compose logs --tail=100 players-web
```

## Troubleshooting

### Players Database Connection Issues

```bash
# Check database is running and healthy
docker inspect players-db-1 | grep -A5 Health

# Test database connection
docker exec -it players-db-1 psql -U postgres -d players_production -c "SELECT 1;"

# Check environment variables in container
docker exec -it players-players-1 env | grep DATABASE
```

### Ghost Database Connection Issues

```bash
# Check MySQL is running
docker inspect ghost-db | grep -A5 Health

# Test database connection
docker exec -it ghost-db mysql -u ghost -p ghost

# Check Ghost logs
docker logs ghost
```

### Image Pull Issues

If you can't pull the players image:

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull manually
docker pull ghcr.io/jamiepinkham/players:main
```

### Network Issues

If containers can't communicate:

```bash
# Verify networks exist
docker network ls

# Inspect web network
docker network inspect web

# Inspect default network
docker network inspect players_default
```

## Configuration Management

### Updating Environment Variables

1. Edit `.env` file
2. Recreate affected containers:

```bash
docker-compose up -d --force-recreate players-web players-scheduler
```

### Updating Caddy Configuration

Caddy configuration is separate. See `caddy/README.md` for details.

## Monitoring

### Container Resource Usage

```bash
docker stats
```

### Database Size

```bash
# Players database
docker exec -it players-db-1 psql -U postgres -d players_production -c "SELECT pg_size_pretty(pg_database_size('players_production'));"

# Ghost database
docker exec -it ghost-db mysql -u ghost -p -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = 'ghost';"
```
