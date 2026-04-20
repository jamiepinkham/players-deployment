# Migration: Replace Current Fenway Setup with New Stack

This guide covers replacing the current running setup on fenway with the new unified stack from this repository.

## Pre-Migration Checklist

- [ ] Database backups completed
- [ ] Environment variables documented
- [ ] Caddy configuration backed up
- [ ] Current docker-compose files backed up (if any)
- [ ] Cloudflared tunnel working
- [ ] Maintenance window scheduled (optional, ~10 min downtime)

## Overview

**Current Setup:**
- Containers: `players-players-1`, `players-db-1`, `players-scheduler-1`, `ghost`, `ghost-db`
- Networks: `players_default`, `ghost_default`, `web`
- Managed via: Portainer (probably separate stacks)

**New Setup:**
- Containers: `players-web`, `players-db`, `players-scheduler`, `ghost`, `ghost-db`
- Networks: `players_default`, `web`
- Managed via: Single Portainer stack (`fenway-apps`)
- Config: Version controlled in GitHub

## Migration Steps

### 1. Backup Everything

```bash
ssh ortiz@fenway

# Backup databases
docker exec players-db-1 pg_dump -U postgres players_production > ~/backup_players_$(date +%Y%m%d_%H%M%S).sql
docker exec ghost-db mysqldump -u ghost -pYOUR_GHOST_DB_PASSWORD ghost > ~/backup_ghost_$(date +%Y%m%d_%H%M%S).sql

# Backup Caddy config (if not already in repo)
docker cp caddy:/etc/caddy/Caddyfile ~/Caddyfile.backup

# Note: If Caddy is using a mounted config file, back that up instead
docker inspect caddy | grep Caddyfile

# List current containers for reference
docker ps > ~/containers_before_migration.txt

# Copy backups off fenway (from your local machine)
scp ortiz@fenway:~/backup_*.sql ~/backups/
```

### 2. Prepare Environment Variables

Create environment variable file locally (already done in `fenway-current-env-values.txt`):

```bash
# Values you need for Portainer:
POSTGRES_PASSWORD=          # (empty - using trust auth)
SECRET_KEY_BASE=YOUR_RAILS_SECRET_KEY_BASE
MAILGUN_SMTP_USERNAME=postmaster@mail.billymartinplayersleague.com
MAILGUN_SMTP_PASSWORD=YOUR_MAILGUN_API_KEY
GHOST_DB_PASSWORD=YOUR_GHOST_DB_PASSWORD
```

### 3. Stop Current Stacks

**Option A: Via Portainer UI**
1. Go to http://fenway:9000
2. Go to Stacks
3. Stop (don't delete yet):
   - Players stack (if it exists)
   - Ghost stack (if it exists)

**Option B: Via Docker CLI**
```bash
ssh ortiz@fenway

# Stop containers (keeps volumes/data intact)
docker stop players-players-1 players-db-1 players-scheduler-1 ghost ghost-db

# Verify they're stopped
docker ps
```

**Downtime starts here** ⏱️

### 4. Deploy New Stack via Portainer

1. **Open Portainer**: http://fenway:9000

2. **Create New Stack**:
   - Click **Stacks** → **Add Stack**
   - Name: `fenway-apps`

3. **Configure Repository**:
   - Build method: **Repository**
   - Repository URL: `https://github.com/jamiepinkham/players-deployment`
   - Repository reference: `main`
   - Compose path: `stack/docker-compose.yml`

4. **Add Environment Variables**:
   Click "Add environment variable" for each (get actual values from `fenway-current-env-values.txt`):
   - Name: `POSTGRES_PASSWORD`, Value: *(leave empty)*
   - Name: `SECRET_KEY_BASE`, Value: `YOUR_RAILS_SECRET_KEY_BASE`
   - Name: `MAILGUN_SMTP_USERNAME`, Value: `postmaster@mail.billymartinplayersleague.com`
   - Name: `MAILGUN_SMTP_PASSWORD`, Value: `YOUR_MAILGUN_API_KEY`
   - Name: `GHOST_DB_PASSWORD`, Value: `YOUR_GHOST_DB_PASSWORD`

5. **Deploy the Stack**

6. **Wait for containers to start** (check Portainer UI or `docker ps`)

### 5. Restore Data to New Containers

The new containers will start with empty databases. Restore from backup:

```bash
ssh ortiz@fenway

# Wait for databases to be healthy
docker ps | grep players-db
docker ps | grep ghost-db

# Restore Players database
docker exec -i players-db psql -U postgres players_production < ~/backup_players_*.sql

# Restore Ghost database
docker exec -i ghost-db mysql -u ghost -pYOUR_GHOST_DB_PASSWORD ghost < ~/backup_ghost_*.sql

# Verify data
docker exec players-db psql -U postgres -d players_production -c "SELECT COUNT(*) FROM users;"
docker exec ghost-db mysql -u ghost -pYOUR_GHOST_DB_PASSWORD ghost -e "SELECT COUNT(*) FROM posts;"
```

**Alternative: Reuse existing volumes**

If you want to keep the existing data volumes without dumping/restoring:

1. Stop new stack
2. Remove new database volumes
3. Rename old volumes to new names
4. Restart new stack

```bash
# Stop new stack
docker stop players-db ghost-db

# Remove empty new volumes
docker volume rm fenway-apps_players-db-data
docker volume rm fenway-apps_ghost-db-data
docker volume rm fenway-apps_ghost-content

# Find old volume names
docker volume ls | grep players
docker volume ls | grep ghost

# Rename old volumes to new names (assuming old volumes are named players_players-db-data, etc.)
# Note: Docker doesn't have a rename command, so we need to create new volumes and copy data

# Actually, easier approach: Update docker-compose.yml to use external volumes
# Or just mount the old volumes by changing the volume names in Portainer stack editor
```

**Easiest: Just update volume names in Portainer**

In Portainer, edit the stack and change volume declarations to point to existing volumes:

```yaml
volumes:
  players-db-data:
    external: true
    name: players_players-db-data  # The actual old volume name
  ghost-db-data:
    external: true
    name: ghost_ghost-db-data
  ghost-content:
    external: true
    name: ghost_ghost-content
```

### 6. Update Caddy Configuration

```bash
ssh ortiz@fenway

# Find where Caddy config is located
docker inspect caddy | grep -A5 Mounts

# Option A: If Caddy mounts a config file from host
# Update that file with the new container names (players-web instead of players-players-1)
# Then reload:
docker exec caddy caddy reload

# Option B: If Caddy config is inside container
# Copy new Caddyfile from repo
git clone https://github.com/jamiepinkham/players-deployment.git
docker cp players-deployment/caddy/Caddyfile caddy:/etc/caddy/Caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verify Caddy can reach new containers
docker exec caddy wget -O- http://players-web:3000 | head
```

### 7. Verify Everything Works

```bash
# Check all containers running
docker ps

# Check logs for errors
docker logs players-web --tail=50
docker logs ghost --tail=50
docker logs players-scheduler --tail=50

# Test database connections
docker exec players-web bundle exec rails runner "puts User.count"
docker exec ghost-db mysql -u ghost -pYOUR_GHOST_DB_PASSWORD ghost -e "SELECT COUNT(*) FROM posts;"

# Test web access (from local machine via SSH tunnel)
curl -I http://fenway:3000

# Test via cloudflare tunnel
curl -I https://billymartinplayersleague.com
```

**Downtime ends here** ⏱️

### 8. Monitor for Issues

Watch logs for a few minutes:

```bash
ssh ortiz@fenway
docker logs -f players-web

# In another terminal
docker logs -f ghost

# Check for any errors
```

### 9. Clean Up Old Containers (Optional)

Once you've verified everything works for 24-48 hours:

```bash
ssh ortiz@fenway

# Remove old stopped containers
docker rm players-players-1 players-db-1 players-scheduler-1

# If ghost containers were separate
docker rm ghost ghost-db  # (if different from new ones)

# Remove old stacks in Portainer
# (Portainer UI → Stacks → Delete old stacks)

# Optional: Clean up old volumes if you migrated data
# ONLY DO THIS IF YOU'RE SURE DATA WAS MIGRATED
docker volume ls  # Review what exists
# docker volume rm <old-volume-name>  # BE CAREFUL!
```

## Rollback Plan

If something goes wrong:

### Quick Rollback (within 1 hour of migration)

```bash
ssh ortiz@fenway

# Stop new stack
docker stop players-web players-db players-scheduler ghost ghost-db

# Start old containers
docker start players-players-1 players-db-1 players-scheduler-1 ghost ghost-db

# Verify old setup works
curl -I http://fenway:3000
```

### Full Rollback (after data migration)

```bash
# Stop and remove new stack
docker stop players-web players-db players-scheduler ghost ghost-db
docker rm players-web players-db players-scheduler ghost ghost-db

# Restore from backup
docker start players-db-1
docker exec -i players-db-1 psql -U postgres players_production < ~/backup_players_TIMESTAMP.sql

# Start old containers
docker start players-players-1 players-scheduler-1 ghost ghost-db

# Restore Caddy config
docker cp ~/Caddyfile.backup caddy:/etc/caddy/Caddyfile
docker exec caddy caddy reload
```

## Expected Downtime

- **5-10 minutes** if reusing existing volumes (no dump/restore)
- **10-20 minutes** if dumping and restoring databases
- **0 minutes** if you run new stack on different ports first, test, then switch

## Zero-Downtime Migration (Advanced)

To avoid downtime:

1. Deploy new stack with **different ports** (3001, 2369)
2. Test at http://fenway:3001
3. Sync data from old to new (live)
4. Update Caddy to point to new containers
5. Reload Caddy (instant switch)
6. Stop old containers

Would you like detailed steps for zero-downtime migration?

## Post-Migration

- [ ] Site accessible at https://billymartinplayersleague.com
- [ ] Login works
- [ ] Database queries successful
- [ ] Background jobs running (check players-scheduler logs)
- [ ] Ghost blog accessible
- [ ] No errors in logs
- [ ] Old containers stopped
- [ ] Backups kept safe
- [ ] Document what was learned

## Ongoing Management

Now that your deployment is in git:

- **Update players app**: Change image tag in Portainer → Pull and redeploy
- **Update ghost**: Change ghost image tag → Redeploy
- **Deploy to QA**: Create `fenway-apps-qa` stack using `docker-compose.qa.yml`
- **Rollback**: Change image tags to previous version → Redeploy
- **Config changes**: Update repo → git pull on fenway (if using docker-compose) or update in Portainer
