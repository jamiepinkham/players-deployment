# Production Scheduler QA Sync

Use the production scheduler container to automatically sync the database to QA.

## Overview

The `players-scheduler` container runs your app's scheduled jobs via `whenever`. You can add a task to sync production data to QA automatically.

## How It Works

The scheduler container:
- ✅ Has access to Docker socket (can run docker commands)
- ✅ Is on both `default` and `qa` networks (can reach both databases)
- ✅ Runs `whenever` cron jobs already
- ✅ Perfect for infrastructure tasks like QA sync

## Setup

### 1. Add Rake Task to Rails App

Create `rails/lib/tasks/qa.rake` in your players repo:

```ruby
namespace :qa do
  desc "Sync production database to QA environment"
  task sync_database: :environment do
    next unless Rails.env.production? # Only run in production

    puts "[#{Time.current}] Starting prod → QA database sync..."

    dump_file = "/tmp/qa_sync_#{Time.current.to_i}.sql"

    begin
      # 1. Dump production database
      puts "Dumping production database..."
      system("pg_dump -U postgres -h players-db players_production > #{dump_file}")

      unless File.size?(dump_file)
        raise "Dump file is empty or missing!"
      end

      puts "Dump created: #{File.size(dump_file) / 1024 / 1024}MB"

      # 2. Stop QA services
      puts "Stopping QA services..."
      system("docker stop players-web-qa players-scheduler-qa 2>/dev/null || true")

      # 3. Reset QA database
      puts "Resetting QA database..."
      system("docker exec players-db-qa psql -U postgres -c 'DROP DATABASE IF EXISTS players_production;'")
      system("docker exec players-db-qa psql -U postgres -c 'CREATE DATABASE players_production;'")

      # 4. Restore to QA
      puts "Restoring to QA..."
      system("cat #{dump_file} | docker exec -i players-db-qa psql -U postgres players_production")

      # 5. Restart QA services
      puts "Restarting QA services..."
      system("docker start players-web-qa players-scheduler-qa")

      # 6. Run migrations on QA (in case QA is testing newer code)
      puts "Running migrations on QA..."
      system("docker exec players-web-qa bundle exec rails db:migrate 2>/dev/null || true")

      puts "[#{Time.current}] ✅ QA sync complete!"

    rescue => e
      puts "[#{Time.current}] ❌ QA sync failed: #{e.message}"
      raise
    ensure
      # Cleanup
      File.delete(dump_file) if File.exist?(dump_file)
    end
  end
end
```

### 2. Add to Whenever Schedule

Edit `rails/config/schedule.rb`:

```ruby
# Sync production to QA daily at 3 AM
every 1.day, at: '3:00 am' do
  rake "qa:sync_database"
end

# Or weekly on Sunday at 2 AM:
# every :sunday, at: '2:00 am' do
#   rake "qa:sync_database"
# end
```

### 3. Deploy Updated Code

```bash
# In players repo
git add rails/lib/tasks/qa.rake rails/config/schedule.rb
git commit -m "Add automated QA database sync task"
git push

# Build and deploy new image
# Portainer will pull the new image on next deployment
```

### 4. Restart Scheduler

```bash
ssh ortiz@fenway
docker restart players-scheduler
```

The scheduler will pick up the new whenever schedule.

## Verify It's Scheduled

Check the crontab inside the scheduler:

```bash
docker exec players-scheduler crontab -l
```

You should see the `qa:sync_database` task scheduled.

## Manual Trigger

Test the sync manually:

```bash
docker exec players-scheduler bundle exec rails qa:sync_database
```

## Monitor Sync

Watch scheduler logs:

```bash
docker logs -f players-scheduler
```

You'll see sync output at scheduled times.

## Timing Recommendations

**Daily at 3 AM (recommended):**
```ruby
every 1.day, at: '3:00 am' do
  rake "qa:sync_database"
end
```
Fresh data every morning for testing.

**Weekly on Sunday:**
```ruby
every :sunday, at: '2:00 am' do
  rake "qa:sync_database"
end
```
Less frequent, lighter load.

**Multiple times per day:**
```ruby
every 6.hours do
  rake "qa:sync_database"
end
```
Very fresh data, but more load.

## Important Notes

### Docker Socket Access

The scheduler has access to Docker socket to run container commands. This is needed for:
- Stopping/starting QA containers
- Executing commands in other containers
- Database restore operations

This is safe because:
- Only the scheduler container has this access
- Only runs in production environment
- Only affects QA containers, not production

### Network Access

The scheduler is on both networks:
- `default` - Production database access
- `qa` - QA database access

This allows it to dump from prod and restore to QA.

### Error Handling

If sync fails:
- Error is logged
- QA services restart anyway (won't stay stopped)
- Temporary dump file is cleaned up
- Next scheduled run will try again

## Troubleshooting

### Sync not running

Check crontab:
```bash
docker exec players-scheduler crontab -l
```

Check scheduler is running:
```bash
docker ps | grep players-scheduler
```

### Permission errors

The scheduler container needs `pg_dump` installed. If missing:
```dockerfile
# In your Dockerfile
RUN apt-get update && apt-get install -y postgresql-client
```

### Docker socket permission denied

Verify socket is mounted:
```bash
docker inspect players-scheduler | grep docker.sock
```

Should show: `/var/run/docker.sock:/var/run/docker.sock`

## Alternative: Simpler Approach

If you don't want Docker socket access, use a simpler database-to-database sync:

```ruby
# Simpler version - just copies data directly
task sync_database: :environment do
  # Connect to QA database
  qa_config = ActiveRecord::Base.configurations.configs_for(env_name: 'production').first.configuration_hash.dup
  qa_config[:host] = 'players-db-qa'

  # Use pg_dump piped to psql
  system("pg_dump -U postgres -h players-db players_production | psql -h players-db-qa -U postgres players_production")
end
```

But this doesn't stop/restart QA services, so may have connection conflicts.

## Disable Sync

Remove from `schedule.rb` or comment out, then:

```bash
docker restart players-scheduler
```
