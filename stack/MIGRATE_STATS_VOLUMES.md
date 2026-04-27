# Migrate bmpl-stats Volumes to Explicit Names

## Context

The bmpl-stats stack volumes are being renamed to match the naming convention used by other stacks (underscores instead of stack-prefixed names).

**Old volumes (auto-generated with stack prefix):**
- `bmpl-stats_stats-db-data`
- `bmpl-stats_stats-redis-data`

**New volumes (explicit names):**
- `stats_db_data`
- `stats_redis_data`

**Data preservation:** Not needed - stats data is just a cache and will rebuild automatically from MLB API.

## Migration Steps

### 1. Stop the bmpl-stats Stack

In Portainer:
- Navigate to **Stacks** → **bmpl-stats**
- Click **Stop this stack**
- Wait for all containers to stop

### 2. Delete Old Volumes

```bash
ssh ortiz@fenway
docker volume rm bmpl-stats_stats-db-data
docker volume rm bmpl-stats_stats-redis-data
```

### 3. Deploy Updated Stack

In Portainer:
- Navigate to **Stacks** → **bmpl-stats** → **Editor**
- Paste the updated `bmpl-stats.yml` content (with explicit volume names)
- Click **Update the stack**
- Wait for containers to start (~30 seconds)

### 4. Initialize Database Schema

```bash
ssh ortiz@fenway
docker exec stats-api alembic upgrade head
```

### 5. Verify Migration

```bash
ssh ortiz@fenway

# Check container health
docker ps | grep stats

# Verify database is accessible
docker exec stats-db psql -U postgres -d players_stats -c "\dt"

# Test API health endpoint
curl http://localhost:3001/api/v1/health
```

### 6. Warm the Cache (Optional)

Trigger a full cache rebuild for all free agents:

```bash
ssh ortiz@fenway

# Quick fire-and-forget (recommended)
docker exec players-web bundle exec rake cache:warmup_quick

# Or with progress output
docker exec players-web bundle exec rake cache:warmup_stats
```

This will trigger async stats fetches for all free agents. Cache will be populated within a few minutes.

Alternatively, skip this step and let stats rebuild organically as players are viewed.

## Expected Downtime

- Stats API unavailable: ~2-3 minutes
- Players apps remain functional (gracefully handle missing stats)
- Stats rebuild automatically as players are viewed

## Post-Migration

Stats cache will rebuild organically as:
- Users browse player pages
- Nightly cron jobs run
- API requests come in

Within 24 hours, frequently accessed stats will be cached again.
