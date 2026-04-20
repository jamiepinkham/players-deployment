# Manual QA Database Sync

Sync production data to QA when needed for testing.

## Quick Sync

```bash
ssh ortiz@fenway
~/players-deployment/scripts/sync-prod-to-qa.sh
```

That's it! The script:
1. Dumps production database
2. Stops QA containers
3. Restores to QA database
4. Restarts QA containers
5. Runs any pending migrations

## When to Sync

Run manual sync:
- ✅ Before testing a new feature
- ✅ After production data changes significantly
- ✅ When QA data gets messy from testing
- ✅ Weekly or as needed

## First Time Setup

```bash
# Clone deployment repo on fenway
ssh ortiz@fenway
cd ~
git clone https://github.com/jamiepinkham/players-deployment.git
```

That's all - the script is already executable.

## Usage

```bash
# Basic sync
ssh ortiz@fenway
~/players-deployment/scripts/sync-prod-to-qa.sh

# Or one-liner from local
ssh ortiz@fenway ~/players-deployment/scripts/sync-prod-to-qa.sh
```

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
