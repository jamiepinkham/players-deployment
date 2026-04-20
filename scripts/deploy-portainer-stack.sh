#!/bin/bash
# Deploy the unified fenway stack to Portainer
#
# Prerequisites:
# - Portainer running on fenway at port 9000
# - Environment variables file with Portainer credentials
# - Stack name: bmpl-apps

set -e

PORTAINER_URL="${PORTAINER_URL:-http://fenway:9000}"
STACK_NAME="bmpl-apps"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Deploying bmpl-apps stack to Portainer"
echo ""

# Check if env files exist
if [ ! -f "$REPO_DIR/env/shared.env" ]; then
  echo "❌ Error: env/shared.env not found"
  echo "   Copy env/shared.env.template and fill in values"
  exit 1
fi

if [ ! -f "$REPO_DIR/env/mailgun.env" ]; then
  echo "❌ Error: env/mailgun.env not found"
  echo "   Copy env/mailgun.env.template and fill in values"
  exit 1
fi

echo "✅ Environment files found"
echo ""
echo "Deployment options:"
echo ""
echo "1. Deploy via Portainer UI (recommended)"
echo "   - Open http://fenway:9000"
echo "   - Stacks → Add Stack"
echo "   - Name: bmpl-apps"
echo "   - Repository: https://github.com/jamiepinkham/players-deployment"
echo "   - Compose path: stack/docker-compose.yml"
echo ""
echo "2. Deploy via Portainer API"
echo "   - Requires Portainer API credentials"
echo "   - Can be automated"
echo ""
echo "3. Deploy via Docker Compose directly"
echo "   - SSH to fenway"
echo "   - cd to deployment directory"
echo "   - docker-compose up -d"
echo ""
read -p "Choose deployment method (1/2/3): " method

case $method in
  1)
    echo ""
    echo "Opening Portainer UI..."
    open "$PORTAINER_URL"
    echo ""
    echo "Follow these steps in Portainer:"
    echo "  1. Click 'Stacks' in the left sidebar"
    echo "  2. Click 'Add stack'"
    echo "  3. Name: bmpl-apps"
    echo "  4. Build method: Repository"
    echo "  5. Repository URL: https://github.com/jamiepinkham/players-deployment"
    echo "  6. Repository reference: main"
    echo "  7. Compose path: stack/docker-compose.yml"
    echo "  8. Add environment variables from env files"
    echo "  9. Click 'Deploy the stack'"
    ;;
  2)
    echo "❌ API deployment not yet implemented"
    echo "   Use method 1 or 3 instead"
    exit 1
    ;;
  3)
    echo ""
    echo "Manual deployment steps:"
    echo ""
    echo "  # 1. Upload stack to fenway"
    echo "  scp -r $REPO_DIR ortiz@fenway:~/players-deployment"
    echo ""
    echo "  # 2. SSH to fenway"
    echo "  ssh ortiz@fenway"
    echo ""
    echo "  # 3. Deploy the stack"
    echo "  cd ~/players-deployment/stack"
    echo "  docker-compose up -d"
    echo ""
    echo "  # 4. View logs"
    echo "  docker-compose logs -f"
    ;;
  *)
    echo "Invalid option"
    exit 1
    ;;
esac
