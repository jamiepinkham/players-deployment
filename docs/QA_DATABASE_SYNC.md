# QA Database Sync

Keep the QA environment in sync with production data automatically.

## Overview

The QA database can be automatically synced from production on a schedule. This ensures:
- ✅ QA has realistic, recent data for testing
- ✅ Feature testing happens with production-like scenarios
- ✅ Migration testing uses actual data structures
- ✅ Bug reproduction with real data patterns

## Setup Automatic Sync

### 1. Copy Script to Fenway

```bash
# From your local machine
scp /Users/jp/dev/players-deployment/scripts/sync-prod-to-qa.sh ortiz@fenway:~/
ssh ortiz@fenway chmod +x ~/sync-prod-to-qa.sh
```

Or if repo is cloned on fenway:
```bash
ssh ortiz@fenway
cd ~/players-deployment
chmod +x scripts/sync-prod-to-qa.sh
```

### 2. Test Manual Sync

```bash
ssh ortiz@fenway
~/sync-prod-to-qa.sh
```

You should see:
- Production database dumped
- QA services stopped
- Database restored
- QA services restarted

### 3. Set Up Cron Schedule

```bash
ssh ortiz@fenway
crontab -e
```

Add one of these schedules:

**Daily at 3 AM:**
```cron
0 3 * * * /home/ortiz/sync-prod-to-qa.sh >> /home/ortiz/logs/qa-sync.log 2>&1
```

**Every Sunday at 2 AM:**
```cron
0 2 * * 0 /home/ortiz/sync-prod-to-qa.sh >> /home/ortiz/logs/qa-sync.log 2>&1
```

**Every 6 hours:**
```cron
0 */6 * * * /home/ortiz/sync-prod-to-qa.sh >> /home/ortiz/logs/qa-sync.log 2>&1
```

### 4. Create Log Directory

```bash
ssh ortiz@fenway
mkdir -p ~/logs
```

## Manual Sync

Sync production to QA anytime:

```bash
ssh ortiz@fenway
~/sync-prod-to-qa.sh
```

## What the Sync Does

1. **Dumps production database** to temporary file
2. **Stops QA web/scheduler** to prevent connection conflicts
3. **Drops QA database** completely
4. **Recreates fresh QA database**
5. **Restores production data** to QA
6. **Restarts QA services**
7. **Runs any pending migrations** (if QA is testing newer code)
8. **Cleans up** temporary dump file

## Important Notes

### Data Privacy

⚠️ **QA will have real production data!**

If your production has sensitive user data:
- Consider sanitizing before sync (scrub emails, passwords, PII)
- Restrict QA access to trusted developers only
- Don't expose QA publicly

### Sync Timing

Choose sync timing based on:
- **Daily (3 AM)** - Fresh data every morning for testing
- **Weekly (Sunday)** - Less frequent, good for stable QA
- **On-demand** - Manual sync before major testing sessions

### QA Code vs Production Code

If QA is testing a **newer** branch with new migrations:
- Sync will restore prod data
- Then run any new migrations automatically
- This tests the migration path!

If QA is testing an **older** branch:
- Sync might fail if prod has newer schema
- Keep QA on same or newer code than prod

## Monitoring

Check sync logs:
```bash
ssh ortiz@fenway
tail -f ~/logs/qa-sync.log
```

Check last sync:
```bash
ssh ortiz@fenway
grep "Sync complete" ~/logs/qa-sync.log | tail -1
```

## Troubleshooting

### Sync fails with "database in use"

QA services didn't stop cleanly. Manually stop:
```bash
docker stop players-web-qa players-scheduler-qa
docker exec players-db-qa psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'players_production';"
```

Then re-run sync.

### Sync takes too long

Large database? Add compression:
```bash
# Modify script to use compressed dump
docker exec players-db pg_dump -U postgres players_production | gzip > "$DUMP_FILE.gz"
gunzip -c "$DUMP_FILE.gz" | docker exec -i players-db-qa psql -U postgres players_production
```

### Want to keep some QA-only data

Modify script to exclude certain tables:
```bash
docker exec players-db pg_dump -U postgres \
  --exclude-table=test_data \
  players_production > "$DUMP_FILE"
```

## Alternative: Anonymized Sync

For sensitive production data, create an anonymized version:

```bash
# After restore, anonymize in QA
docker exec players-web-qa bundle exec rails runner "
  User.find_each do |u|
    u.update_columns(
      email: \"user-#{u.id}@example.com\",
      first_name: 'Test',
      last_name: \"User-#{u.id}\"
    )
  end
"
```

Add this to the sync script after the restore step.

## Disable Automatic Sync

Remove from cron:
```bash
ssh ortiz@fenway
crontab -e
# Delete or comment out the sync line
```

Manual sync will still work via `~/sync-prod-to-qa.sh`.
