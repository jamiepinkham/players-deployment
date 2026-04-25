# Deployment Guide - BMPL Stack

**Current deployment method:** Portainer UI on fenway

This guide covers common deployment operations for the consolidated `bmpl` stack.

## Current Architecture

All services run in a single Portainer stack named `bmpl` on fenway.

**Access:**
- Portainer: http://fenway:9000 (via SSH tunnel)
- Production: https://players.billymartinplayersleague.com
- QA: https://qa.billymartinplayersleague.com
- Ghost: https://billymartinplayersleague.com

## Common Operations

### Viewing Stack Status

**Via Portainer:**
1. Navigate to Stacks → `bmpl`
2. View all 14 services with their status
3. Click any service to view logs or restart

**Via SSH:**
```bash
ssh ortiz@fenway
docker ps  # View all running containers
docker ps --format 'table {{.Names}}\t{{.Status}}'  # Cleaner view
```

### Updating Environment Variables

1. **Stacks → bmpl → Editor**
2. Scroll to **Environment variables** section
3. Update variables (e.g., `GIT_REF` for QA branch)
4. Click **Update the stack**

### Updating the Stack Configuration

1. Edit `stack/docker-compose.consolidated.yml` locally
2. **Stacks → bmpl → Editor**
3. Paste updated compose file
4. Click **Update the stack**

### Viewing Logs

**Via Portainer:**
1. Stacks → bmpl → Click service name (e.g., `players-web`)
2. Click **Logs** tab
3. Use filters and search as needed

**Via SSH:**
```bash
ssh ortiz@fenway

# View logs for a specific service
docker logs -f players-web
docker logs -f players-web-qa
docker logs -f ghost

# Last 50 lines
docker logs --tail 50 players-web

# Follow logs
docker logs -f players-web
```

### Restarting Services

**Via Portainer:**
1. Stacks → bmpl → Click service
2. Click **Restart** button

**Via SSH:**
```bash
ssh ortiz@fenway

docker restart players-web
docker restart players-web-qa
docker restart ghost
```

### Cache Warmup After Restart

**Problem:** When Rails containers restart, Redis cache may be empty, causing:
- Spinners on free agents page that never resolve
- Slow initial page loads
- Background jobs need minutes to repopulate cache

**Solution:** Manually warm the cache after restart:

```bash
ssh ortiz@fenway

# Quick warmup - top 100 free agents (5-10 seconds)
docker exec players-web rails cache:warmup_quick
docker exec players-web-qa rails cache:warmup_quick

# Full warmup - all players with stats (1-2 minutes)
docker exec players-web rails cache:warmup
docker exec players-web-qa rails cache:warmup
```

**Why it's fast:** Loads stats from `player_stats` database table instead of re-fetching from MLB API.

**When to use:**
- After restarting web containers
- After Redis container restart
- After running `players:remove_ineligible` cleanup
- When free agents page shows endless spinners

**See:** `rails/CACHE_WARMUP.md` in players repo for full documentation.

### Updating Rails Application

When a new image is pushed to GitHub Container Registry:

```bash
ssh ortiz@fenway

# Pull latest image
docker pull ghcr.io/jamiepinkham/players:main

# Restart production services
docker restart players-web players-sidekiq players-scheduler
```

Or in Portainer:
1. Stacks → bmpl → Editor
2. Check **Re-pull images and redeploy**
3. Click **Update the stack**

### Updating QA Branch

To deploy a different branch to QA:

1. **Stacks → bmpl → Editor**
2. **Environment variables** → Find `GIT_REF`
3. Change to your branch name (e.g., `GIT_REF=feature-branch`)
4. Click **Update the stack**

### Database Backups

```bash
ssh ortiz@fenway

# Production database
docker exec players-db pg_dumpall -U postgres > /tmp/players_backup_$(date +%Y%m%d).sql

# QA database
docker exec players-db-qa pg_dumpall -U postgres > /tmp/players_qa_backup_$(date +%Y%m%d).sql

# Ghost database
docker exec ghost-db mysqldump -u root -pdjshklxzvbcsajlk ghost > /tmp/ghost_backup_$(date +%Y%m%d).sql

# View backups
ls -lh /tmp/*.sql
```

## Troubleshooting

### Container Not Starting

1. Check logs in Portainer or via SSH:
   ```bash
   docker logs <container-name> --tail 50
   ```

2. Common issues:
   - **Environment variables missing:** Check env vars in Portainer stack editor
   - **Database not ready:** Wait for database health check to pass
   - **Port conflicts:** Ensure no other services using the same ports

### Database Connection Errors

```bash
# Check database containers
docker ps | grep db

# Check database health
docker inspect players-db | grep -A5 Health
docker inspect ghost-db | grep -A5 Health

# Test connection
docker exec players-db psql -U postgres -d players_production -c "SELECT 1;"
docker exec ghost-db mysql -u ghost -pdjshklxzvbcsajlk ghost -e "SELECT 1;"
```

**PostgreSQL Authentication Issue:**

If Rails apps fail with "password authentication failed for user postgres" but direct psql works:

```bash
# Fix: Change PostgreSQL to trust authentication
docker exec players-db bash -c "sed -i 's/scram-sha-256/trust/g' /var/lib/postgresql/data/pg_hba.conf"
docker exec players-db psql -U postgres -c 'SELECT pg_reload_conf();'

# Verify fix
docker exec players-web rails runner 'puts User.count'
```

This can happen after recreating database volumes. The fix persists in the volume.

### Ghost Login Issues

If Ghost shows "too many login attempts":

```bash
ssh ortiz@fenway
docker exec ghost-db mysql -u ghost -pdjshklxzvbcsajlk ghost -e "TRUNCATE TABLE brute;"
```

**Critical:** Ensure only ONE ghost container is running:
```bash
docker ps -a | grep ghost
# Should only show: ghost and ghost-db
```

### Network Connectivity Issues

```bash
# Check networks
docker network ls

# Inspect web network
docker network inspect web

# Should show: caddy, cloudflared, players-web, players-web-qa, ghost, portainer
```

### Sidekiq Not Running (Production)

Production sidekiq will fail if the `main` image doesn't include sidekiq gem. This is expected if:
- The feature is in QA but not yet merged to main
- The main branch image needs to be rebuilt

QA sidekiq works because it uses the branch image with sidekiq installed.

## Monitoring

### Resource Usage

```bash
ssh ortiz@fenway
docker stats

# Or specific containers
docker stats players-web players-db ghost
```

### Database Sizes

```bash
# Production database size
docker exec players-db psql -U postgres -d players_production -c "SELECT pg_size_pretty(pg_database_size('players_production'));"

# Ghost database size
docker exec ghost-db mysql -u ghost -pdjshklxzvbcsajlk -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = 'ghost';"
```

### Disk Usage

```bash
ssh ortiz@fenway

# Docker disk usage
docker system df

# Volume sizes
docker volume ls | grep -E '(players|ghost|caddy)' | while read driver name; do
  size=$(docker volume inspect $name --format '{{.Mountpoint}}' | xargs du -sh 2>/dev/null | cut -f1)
  echo "$name: $size"
done
```

## Rollback

If an update causes issues:

1. **Via Portainer:** Stacks → bmpl → Editor → Revert to previous compose file
2. **Via SSH:** Restart with known-good configuration

For database rollback, restore from backup:
```bash
# Restore production database
docker exec -i players-db psql -U postgres < /tmp/players_backup_YYYYMMDD.sql

# Restore Ghost database
docker exec -i ghost-db mysql -u root -pdjshklxzvbcsajlk ghost < /tmp/ghost_backup_YYYYMMDD.sql
```

## Additional Documentation

- **stack/README.md** - Detailed stack architecture and configuration
- **Main README.md** - Repository overview

## Support

For issues or questions:
- Check logs first (Portainer or SSH)
- Review stack/README.md for configuration details
- GitHub Issues: https://github.com/jamiepinkham/players-deployment/issues
