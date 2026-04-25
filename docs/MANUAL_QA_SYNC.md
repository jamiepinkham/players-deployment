# Manual QA Database Sync

Sync production data to QA when needed for testing.

## Setup

The sync script needs to be copied to fenway (this repo stays local).

**One-time setup:**

```bash
# Copy the script to fenway
scp scripts/sync-prod-to-qa.sh ortiz@fenway:/tmp/sync-prod-to-qa.sh
ssh ortiz@fenway chmod +x /tmp/sync-prod-to-qa.sh
```

## Usage

```bash
ssh ortiz@fenway /tmp/sync-prod-to-qa.sh
```

The script:
1. Dumps production database
2. Stops QA containers
3. Restores to QA database
4. Restarts QA containers
5. Runs any pending migrations
6. Populates player stats cache (prevents "stats not found" on first page load)

## When to Sync

- ✅ Before testing a new feature
- ✅ After production data changes significantly
- ✅ When QA data gets messy from testing
- ✅ Weekly or as needed

## What Gets Synced

✅ **All production data** - Users, teams, players, bids, trades, etc.
✅ **Database schema** - Same structure as production
✅ **Migrations** - Automatically runs any new migrations on QA

❌ **Not synced** - Uploaded files, storage (only database)

## After Sync

QA will have:
- Fresh production data
- Latest schema from production
- Any new migrations applied
- Pre-populated stats cache (no waiting for background jobs)

Test your features with realistic data!

## Troubleshooting

### Sync fails

Check containers are running:
```bash
docker ps | grep players
docker ps | grep bmpl
```

### Database locked

If dump fails, check connections:
```bash
docker exec players-db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'players_production';"
```

### Out of disk space

Check available space:
```bash
ssh ortiz@fenway df -h
```

The dump is temporary and cleaned up automatically.

## Reset QA Without Prod Data

Want a fresh empty QA database instead?

```bash
ssh ortiz@fenway
docker exec players-web-qa bundle exec rails db:reset
```

This gives you a clean slate with just the schema.

## Manual Sync is Better

**Why manual > automated:**
- ✅ No security risks (no Docker socket access)
- ✅ Sync when you actually need it
- ✅ Don't waste resources syncing when QA isn't in use
- ✅ Simple, predictable
- ✅ Easy to troubleshoot

For a small team, manual sync as-needed is perfect.
