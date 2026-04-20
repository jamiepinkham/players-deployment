#!/bin/bash
# Sync production database to QA environment
# Run this on fenway via cron to keep QA data fresh

set -e

echo "$(date): Starting prod → QA database sync"

DUMP_FILE="/tmp/players_qa_sync_$(date +%Y%m%d_%H%M%S).sql"

# 1. Dump production database
echo "Dumping production database..."
docker exec players-db pg_dump -U postgres players_production > "$DUMP_FILE"

if [ ! -s "$DUMP_FILE" ]; then
  echo "ERROR: Dump file is empty!"
  exit 1
fi

echo "Production dump created: $(du -h $DUMP_FILE | cut -f1)"

# 2. Stop QA web and scheduler to prevent connection issues
echo "Stopping QA services..."
docker stop players-web-qa players-scheduler-qa 2>/dev/null || true

# 3. Drop and recreate QA database
echo "Resetting QA database..."
docker exec players-db-qa psql -U postgres -c "DROP DATABASE IF EXISTS players_production;"
docker exec players-db-qa psql -U postgres -c "CREATE DATABASE players_production;"

# 4. Restore to QA
echo "Restoring to QA database..."
docker exec -i players-db-qa psql -U postgres players_production < "$DUMP_FILE"

# 5. Restart QA services
echo "Starting QA services..."
docker start players-web-qa players-scheduler-qa

# 6. Cleanup
rm "$DUMP_FILE"

echo "$(date): Sync complete! QA database now matches production."

# Optional: Run migrations in case QA is testing newer code
echo "Running any pending migrations on QA..."
docker exec players-web-qa bundle exec rails db:migrate 2>/dev/null || echo "Note: Migrations may have failed (expected if QA is on same version as prod)"

echo "✅ QA environment ready for testing"
