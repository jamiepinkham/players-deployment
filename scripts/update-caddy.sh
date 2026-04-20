#!/bin/bash
# Update Caddy configuration on fenway
# Usage: ssh fenway 'bash -s' < scripts/update-caddy.sh

set -e

echo "🔄 Updating Caddyfile..."

# Download latest Caddyfile from GitHub
curl -sL https://raw.githubusercontent.com/jamiepinkham/players-deployment/main/caddy/Caddyfile -o /tmp/Caddyfile.new

# Find Caddy container and config location
CADDY_CONTAINER=$(docker ps --filter "name=caddy" --format "{{.Names}}" | head -1)

if [ -z "$CADDY_CONTAINER" ]; then
    echo "❌ Caddy container not found!"
    exit 1
fi

echo "✅ Found Caddy container: $CADDY_CONTAINER"

# Copy new config into container
docker cp /tmp/Caddyfile.new $CADDY_CONTAINER:/etc/caddy/Caddyfile

# Validate and reload
echo "🔍 Validating Caddy configuration..."
if docker exec $CADDY_CONTAINER caddy validate --config /etc/caddy/Caddyfile; then
    echo "✅ Configuration valid, reloading..."
    docker exec $CADDY_CONTAINER caddy reload --config /etc/caddy/Caddyfile
    echo "✅ Caddy reloaded successfully!"
    echo ""
    echo "📋 Active routes:"
    echo "  - players.billymartinplayersleague.com → players-web:3000"
    echo "  - qa.billymartinplayersleague.com → players-web-qa:3000"
    echo "  - billymartinplayersleague.com → ghost:2368"
else
    echo "❌ Configuration invalid! Not reloading."
    exit 1
fi

# Cleanup
rm /tmp/Caddyfile.new
