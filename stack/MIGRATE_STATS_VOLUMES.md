# Migrate bmpl-stats Volumes to Explicit Names

## Context

The bmpl-stats stack was originally deployed without explicit volume names, causing Docker Compose to auto-prefix them with the stack name. This migration renames the volumes to match the naming convention used by other stacks.

**Current volumes:**
- `bmpl-stats_stats_db_data` → `stats_db_data`
- `bmpl-stats_stats_redis_data` → `stats_redis_data`

## Prerequisites

- SSH access to fenway
- No active stats API requests (coordinate with team)
- Backup of stats database (optional but recommended)

## Migration Steps

### 1. Optional: Backup Stats Database

```bash
ssh ortiz@fenway
docker exec stats-db pg_dump -U postgres players_stats > ~/stats-backup-$(date +%Y%m%d).sql
```

### 2. Stop the bmpl-stats Stack

In Portainer:
- Navigate to **Stacks** → **bmpl-stats**
- Click **Stop this stack**
- Wait for all containers to stop

Or via SSH:
```bash
ssh ortiz@fenway
docker stop stats-api stats-worker stats-db stats-redis
```

### 3. Rename the Volumes

```bash
ssh ortiz@fenway

# Create new volumes with correct names
docker volume create stats_db_data
docker volume create stats_redis_data

# Copy data from old volumes to new volumes using temporary containers
# For PostgreSQL data
docker run --rm \
  -v bmpl-stats_stats_db_data:/source:ro \
  -v stats_db_data:/target \
  alpine sh -c "cp -av /source/. /target/"

# For Redis data
docker run --rm \
  -v bmpl-stats_stats_redis_data:/source:ro \
  -v stats_redis_data:/target \
  alpine sh -c "cp -av /source/. /target/"
```

### 4. Deploy Updated Stack

In Portainer:
- Navigate to **Stacks** → **bmpl-stats** → **Editor**
- Paste the updated `bmpl-stats.yml` content (with explicit volume names)
- Click **Update the stack**
- Wait for services to become healthy

### 5. Verify Migration

```bash
ssh ortiz@fenway

# Check container health
docker ps | grep stats

# Verify database is accessible
docker exec stats-db psql -U postgres -d players_stats -c "\dt"

# Test API health endpoint
curl http://localhost:3001/api/v1/health

# Check stats are still cached
docker exec stats-api python3 -c "import redis; r = redis.Redis(host='stats-redis', port=6379); print('Keys:', r.dbsize())"
```

### 6. Cleanup Old Volumes (After Confirming Success)

**IMPORTANT: Only do this after verifying the migration worked!**

```bash
ssh ortiz@fenway

# Remove old volumes
docker volume rm bmpl-stats_stats_db_data
docker volume rm bmpl-stats_stats_redis_data
```

## Rollback Plan

If something goes wrong:

1. Stop the bmpl-stats stack
2. In Portainer, revert to the old `bmpl-stats.yml` (without explicit volume names)
3. Redeploy the stack - it will reconnect to the original volumes
4. Delete the new volumes if they were created

## Estimated Downtime

- Stats API will be unavailable for ~5-10 minutes
- Players prod/QA apps will still work (fall back to database/mock mode)
- No impact on end users

## Post-Migration

Update this document's status or delete it once migration is complete.
