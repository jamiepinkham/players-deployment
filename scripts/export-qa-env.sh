#!/bin/bash
# Export environment variables from production stack for QA setup
# Run this on fenway to extract the secrets from production containers

set -e

echo "# QA Environment Variables - Copy/Paste into Portainer"
echo "# =================================================="
echo ""
echo "# Branch to deploy"
echo "GIT_REF=jp/consolidated-fa-improvements"
echo ""
echo "# Database"
echo "DATABASE_NAME=players_qa"
echo ""

# Try to get secrets from production container
if docker inspect players-web &>/dev/null; then
    echo "# Rails Secrets (from production)"
    docker inspect players-web --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E "^(SECRET_KEY_BASE|MAILGUN_SMTP_USERNAME|MAILGUN_SMTP_PASSWORD|POSTGRES_PASSWORD)=" || echo "# Could not extract secrets automatically"
else
    echo "# Production container 'players-web' not found"
    echo "# Please manually copy these from your production stack:"
    echo "SECRET_KEY_BASE="
    echo "MAILGUN_SMTP_USERNAME="
    echo "MAILGUN_SMTP_PASSWORD="
    echo "POSTGRES_PASSWORD="
fi

echo ""
echo "# =================================================="
echo "# Instructions:"
echo "# 1. Copy the above variables"
echo "# 2. Go to Portainer → Stacks → Add stack"
echo "# 3. Name: bmpl-apps-qa"
echo "# 4. Web editor: Use stack/docker-compose.qa.yml"
echo "# 5. Environment variables: Paste the variables above"
echo "# 6. Deploy the stack"
