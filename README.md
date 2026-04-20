# Players Deployment Configuration

This repository contains all deployment configuration for the Players fantasy baseball application and Ghost blog hosted on fenway.

## Problem Statement

This repo solves three critical deployment issues:

1. **Caddy config not in source control** - Reverse proxy configuration was only on the server
2. **Scattered credentials** - Players, DB, and scheduler containers each had their own copies of shared credentials
3. **Mailgun credential duplication** - Mailgun API credentials duplicated between players and ghost stacks

## Solution

A single unified Portainer stack containing:
- Players Rails app (web + scheduler + database)
- Ghost blog (app + database)
- Centralized credentials shared across all services

## Repository Structure

```
players-deployment/
├── stack/              # Unified Portainer stack
│   ├── docker-compose.yml    # All services in one compose file
│   └── README.md             # Stack deployment guide
├── caddy/              # Caddy reverse proxy configuration
│   └── Caddyfile       # Main Caddy config
├── env/                # Environment variable templates
│   ├── shared.env.template      # Credentials shared across containers
│   ├── mailgun.env.template     # Mailgun credentials (players + ghost)
│   ├── players.env.template     # Players-specific vars
│   └── ghost.env.template       # Ghost-specific vars
├── scripts/            # Deployment and management scripts
└── docs/               # Deployment documentation
```

## Setup

### 1. Clone the Repository

```bash
git clone git@github.com:jamiepinkham/players-deployment.git
cd players-deployment
```

### 2. Create Environment Files

Copy the template files and fill in actual values:

```bash
# Shared credentials
cp env/shared.env.template env/shared.env
cp env/mailgun.env.template env/mailgun.env

# App-specific configs
cp env/players.env.template env/players.env
cp env/ghost.env.template env/ghost.env
```

**IMPORTANT:** Never commit the actual `.env` files - they contain secrets!

### 3. Deploy Stack

Deploy via Portainer UI or use the deployment script:

```bash
./scripts/deploy-portainer-stack.sh
```

See `stack/README.md` for detailed deployment options.

## Environment Variables

### Shared Credentials (shared.env)

Used by: players-web, players-scheduler, players-db

- Database connection settings
- Common application secrets

### Mailgun Credentials (mailgun.env)

Used by: players stack, ghost stack

- `MAILGUN_API_KEY`
- `MAILGUN_DOMAIN`
- `MAILGUN_FROM_EMAIL`

### Players-Specific (players.env)

- Rails-specific configuration
- Feature flags
- External API keys

### Ghost-Specific (ghost.env)

- Ghost blog configuration
- Theme settings

## Security

- All `.env` files are gitignored
- Only `.env.template` files are committed
- Templates show structure but use `REDACTED` for actual values
- Actual credentials are managed separately (1Password, etc.)

## Deployment

See `docs/DEPLOYMENT.md` for detailed deployment procedures.

## Rollback

See `docs/ROLLBACK.md` for rollback procedures.
