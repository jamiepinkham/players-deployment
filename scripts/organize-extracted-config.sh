#!/bin/bash
# Organize extracted fenway configuration into repo structure
#
# Usage: ./organize-extracted-config.sh <fenway-config-directory>
#
# This script takes the output from extract-fenway-config.sh and
# organizes it into the players-deployment repository structure.

set -e

if [ $# -eq 0 ]; then
  echo "Usage: $0 <fenway-config-directory>"
  echo ""
  echo "Example: $0 fenway-config-20260419-143022"
  exit 1
fi

EXTRACTED_DIR="$1"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$EXTRACTED_DIR" ]; then
  echo "Error: Directory not found: $EXTRACTED_DIR"
  exit 1
fi

echo "🔧 Organizing extracted configuration..."
echo "  Source: $EXTRACTED_DIR"
echo "  Target: $REPO_DIR"
echo ""

# 1. Caddy configuration
echo "📁 Processing Caddy configuration..."
if [ -f "$EXTRACTED_DIR/caddy/Caddyfile" ]; then
  cp "$EXTRACTED_DIR/caddy/Caddyfile" "$REPO_DIR/caddy/"
  echo "  ✅ Caddyfile copied"
elif [ -f "$EXTRACTED_DIR/caddy/Caddyfile.sudo" ]; then
  cp "$EXTRACTED_DIR/caddy/Caddyfile.sudo" "$REPO_DIR/caddy/Caddyfile"
  echo "  ✅ Caddyfile (sudo) copied"
elif [ -f "$EXTRACTED_DIR/caddy/Caddyfile.home" ]; then
  cp "$EXTRACTED_DIR/caddy/Caddyfile.home" "$REPO_DIR/caddy/Caddyfile"
  echo "  ✅ Caddyfile (home) copied"
else
  echo "  ⚠️  No Caddyfile found"
fi

# 2. Docker Compose files (for reference)
echo ""
echo "🐳 Processing Docker Compose files (saving to docs for reference)..."
mkdir -p "$REPO_DIR/docs/original-configs"
if [ -f "$EXTRACTED_DIR/docker/players-docker-compose.yml" ]; then
  cp "$EXTRACTED_DIR/docker/players-docker-compose.yml" "$REPO_DIR/docs/original-configs/players-docker-compose.yml"
  echo "  ✅ Players docker-compose.yml saved to docs/original-configs/"
else
  echo "  ⚠️  No players docker-compose.yml found"
fi

if [ -f "$EXTRACTED_DIR/docker/ghost-docker-compose.yml" ]; then
  cp "$EXTRACTED_DIR/docker/ghost-docker-compose.yml" "$REPO_DIR/docs/original-configs/ghost-docker-compose.yml"
  echo "  ✅ Ghost docker-compose.yml saved to docs/original-configs/"
else
  echo "  ⚠️  No ghost docker-compose.yml found"
fi

echo "  ℹ️  Original configs saved for reference. The unified stack is in stack/docker-compose.yml"

# 3. Create documentation from extracted info
echo ""
echo "📝 Creating documentation..."

# System info
if [ -f "$EXTRACTED_DIR/logs/system-info.txt" ]; then
  cat > "$REPO_DIR/docs/SYSTEM_INFO.md" <<EOF
# Fenway System Information

Extracted: $(date)

## System Details

\`\`\`
$(cat "$EXTRACTED_DIR/logs/system-info.txt")
\`\`\`

## Docker Version

\`\`\`
$(cat "$EXTRACTED_DIR/logs/docker-version.txt" 2>/dev/null || echo "Not available")
\`\`\`

## Disk Usage

\`\`\`
$(cat "$EXTRACTED_DIR/logs/disk-usage.txt" 2>/dev/null || echo "Not available")
\`\`\`

## Running Containers

\`\`\`
$(cat "$EXTRACTED_DIR/docker/running-containers.txt" 2>/dev/null || echo "Not available")
\`\`\`
EOF
  echo "  ✅ SYSTEM_INFO.md created"
fi

# Credential file locations
if [ -f "$EXTRACTED_DIR/logs/credential-files.txt" ]; then
  cat > "$REPO_DIR/docs/CREDENTIAL_LOCATIONS.md" <<EOF
# Credential File Locations on Fenway

These are the locations where credentials were found on fenway.
Use this to identify which credentials need to be centralized.

\`\`\`
$(cat "$EXTRACTED_DIR/logs/credential-files.txt")
\`\`\`
EOF
  echo "  ✅ CREDENTIAL_LOCATIONS.md created"
fi

# Cron jobs
if [ -f "$EXTRACTED_DIR/logs/crontab.txt" ]; then
  cat > "$REPO_DIR/docs/CRON_JOBS.md" <<EOF
# Cron Jobs on Fenway

\`\`\`
$(cat "$EXTRACTED_DIR/logs/crontab.txt")
\`\`\`
EOF
  echo "  ✅ CRON_JOBS.md created"
fi

echo ""
echo "✅ Organization complete!"
echo ""
echo "Next steps:"
echo "  1. Review the organized files in $REPO_DIR"
echo "  2. Compare docs/original-configs/*.yml with stack/docker-compose.yml"
echo "  3. Update env/*.env.template files with actual variable names from:"
echo "     - $EXTRACTED_DIR/env-templates/"
echo "     - $EXTRACTED_DIR/env-templates/*-env.txt"
echo "  4. Update stack/docker-compose.yml with correct image names and settings"
echo "  5. Verify shared credentials are properly centralized"
echo "  6. Test the unified stack locally before deploying to fenway"
echo "  7. Commit the changes to the players-deployment repo"
echo ""
