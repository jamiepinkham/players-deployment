# BMPL Deployment Architecture

This document describes the current production deployment setup for the Billy Martin Players League platform.

## Architecture Overview

The platform is split into **4 independent Docker Compose stacks**:

1. **bmpl-edge** - Caddy reverse proxy + Cloudflare tunnel
2. **bmpl-players-prod** - Production Rails application
3. **bmpl-players-qa** - QA/Staging Rails application
4. **bmpl-blog** - Ghost CMS for league website

### Why Separate Stacks?

- **Independent deployments** - Update QA without touching production
- **Isolated failures** - Issues in one stack don't cascade
- **Easier rollbacks** - Roll back individual components
- **Better resource management** - Restart only what you need

## Network Architecture

All stacks communicate via shared Docker networks:

- **web** - External network connecting Caddy to all web containers
- **bmpl-prod** - Internal network for production database/redis
- **bmpl-qa** - Internal network for QA database/redis
- **bmpl-blog** - Internal network for Ghost database

```
Internet → Cloudflare Tunnel → Caddy (web network) → Application containers
                                  ↓
                        players-web, players-web-qa, ghost
                                  ↓
                        Internal networks for databases
```

## Asset Compilation Strategy

### Why Assets Build at Container Startup

The Rails application uses React frontend assets that must be compiled. These assets are:
- **Not committed to git** (app/assets/builds/ is gitignored)
- **Not built during Docker image build** (keeps development experience clean)
- **Built at container startup in deployment**

This approach ensures:
- Local development isn't affected by production build configurations
- Developers can use hot-reload and asset watchers
- Production gets optimized, compiled assets
- No build artifacts pollute the git repository

### How It Works

Both production and QA run this startup sequence:

```bash
yarn install                          # Install npm dependencies
yarn build                            # Compile React app with esbuild → application.js
yarn build:css                        # Compile Sass → application.css
RAILS_ENV=production rails assets:precompile  # Copy to public/ and generate manifest
bin/rails server                      # Start Rails
```

**Important**: Asset precompilation always runs with `RAILS_ENV=production` even in QA. This avoids Sass compilation errors while still allowing the app to run in staging mode.

## Stack Details

### 1. bmpl-edge (Infrastructure)

**Services:**
- `caddy` - Reverse proxy with embedded Caddyfile
- `cloudflared` - Cloudflare tunnel for external access

**Purpose:** Routes all incoming traffic to the appropriate backend service.

**Routing:**
- `players.billymartinplayersleague.com` → `players-web:3000`
- `qa.billymartinplayersleague.com` → `players-web-qa:3000`
- `billymartinplayersleague.com` → `ghost:2368`

**Networks:** `web` (external)

### 2. bmpl-players-prod (Production)

**Services:**
- `players-web` - Rails web server (RAILS_ENV=production)
- `players-db` - PostgreSQL database
- `players-redis` - Redis cache
- `players-scheduler` - Cron jobs via supercronic

**Image:** `ghcr.io/jamiepinkham/players:main` (always :main tag)

**Database:** `players_production`

**Networks:** `bmpl-prod` (internal), `web` (external)

**Notes:**
- Sidekiq disabled (broken in :main image, stats use database fallback)
- Health check on `/up` endpoint
- Assets compiled at startup

### 3. bmpl-players-qa (Staging)

**Services:**
- `players-web-qa` - Rails web server (RAILS_ENV=staging)
- `players-sidekiq-qa` - Background job processor
- `players-scheduler-qa` - Cron jobs via supercronic
- `players-db-qa` - PostgreSQL database
- `players-redis-qa` - Redis cache

**Image:** `ghcr.io/jamiepinkham/players:${GIT_REF:-main}` (configurable branch)

**Database:** `players_qa` (uses ENV var `DATABASE_NAME_QA`)

**Networks:** `bmpl-qa` (internal), `web` (external)

**Special Features:**
- Uses `RAILS_ENV=staging` for email interceptor (logs emails instead of sending)
- GraphiQL available at `/graphiql` for GraphQL testing
- Can deploy from feature branches via `GIT_REF` environment variable
- Runs cache warmup script on startup
- Full Sidekiq support (unlike production)

### 4. bmpl-blog (Ghost CMS)

**Services:**
- `ghost` - Ghost CMS application
- `ghost-db` - MySQL database

**Database:** `ghost`

**Networks:** `bmpl-blog` (internal), `web` (external)

**Mail:** Configured with Mailgun SMTP via environment variables

## Deployment Workflow

### Initial Setup

1. Create external networks (one-time):
```bash
ssh ortiz@fenway
docker network create web
docker network create bmpl-prod
docker network create bmpl-qa
docker network create bmpl-blog
```

2. Deploy stacks in Portainer in this order:
   - bmpl-edge (must be first)
   - bmpl-blog, bmpl-players-prod, bmpl-players-qa (any order)

### Updating Production

1. Merge changes to `main` branch
2. Wait for GitHub Actions to build new `:main` image
3. In Portainer: **Stacks → bmpl-players-prod → Editor**
4. Check **"Re-pull images and redeploy"**
5. Click **"Update the stack"**
6. Wait ~3 minutes for asset compilation and startup

### Updating QA

1. Push changes to feature branch
2. Wait for GitHub Actions to build branch image
3. In Portainer: **Stacks → bmpl-players-qa → Editor**
4. Update `GIT_REF` environment variable to your branch name
5. Check **"Re-pull images and redeploy"**
6. Click **"Update the stack"**
7. Wait ~3 minutes for asset compilation and startup

### Updating Infrastructure

1. In Portainer: **Stacks → bmpl-edge → Editor**
2. Modify Caddyfile or other configuration
3. Click **"Update the stack"**
4. ⚠️ Brief interruption to all traffic (Caddy restarts)

## Environment Variables

### Production (.env.production)
- `SECRET_KEY_BASE` - Rails secret
- `POSTGRES_PASSWORD` - Database password (empty = trust auth)
- `MAILGUN_SMTP_USERNAME` - Email credentials
- `MAILGUN_SMTP_PASSWORD` - Email credentials

### QA (.env.qa)
- `SECRET_KEY_BASE_QA` - Rails secret for QA
- `POSTGRES_PASSWORD_QA` - Database password (empty = trust auth)
- `DATABASE_NAME_QA` - Database name (defaults to `players_qa`)
- `GIT_REF` - Git branch to deploy (e.g., `jp-consolidated-fa-improvements`)
- `MAILGUN_SMTP_USERNAME` - Email credentials (intercepted, not sent)
- `MAILGUN_SMTP_PASSWORD` - Email credentials (intercepted, not sent)

### Edge (.env.edge)
- `CLOUDFLARE_TUNNEL_TOKEN` - Cloudflare tunnel authentication

### Ghost (.env.blog)
- `GHOST_DB_PASSWORD` - MySQL password
- `GHOST_MAIL_USER` - Mailgun SMTP username
- `GHOST_MAIL_PASSWORD` - Mailgun SMTP password
- `GHOST_MAIL_FROM` - From address for emails

## Troubleshooting

### "application.js not present in the asset pipeline"

**Cause:** Assets failed to compile during container startup

**Fix:**
1. Check container logs: `docker logs players-web` or `docker logs players-web-qa`
2. Look for errors during `yarn build` or `rails assets:precompile`
3. Common issues:
   - Out of memory during asset compilation
   - Sass syntax errors (ensure using `RAILS_ENV=production` for precompile)
   - Missing node_modules

### Container keeps restarting

**Cause:** Startup command is failing

**Fix:**
1. Check logs: `docker logs <container-name> --tail 100`
2. Look for the specific error (database connection, asset compilation, etc.)
3. Verify environment variables are set correctly

### 502 Bad Gateway

**Cause:** Caddy can't reach the backend container

**Possibilities:**
1. Container is still starting (wait 3 minutes for asset compilation)
2. Container crashed (check logs)
3. Container not on `web` network (check `docker network inspect web`)
4. Wrong container name in Caddyfile

### QA emails being sent to real users

**Cause:** Not using staging environment

**Fix:**
1. Verify `RAILS_ENV=staging` in QA stack environment variables
2. Check logs for "📧 Staging email interceptor registered"
3. Emails should log "EMAIL INTERCEPTED (Staging - Not Sent)"

## Key Conventions

- **Stack naming:** All stacks use `bmpl-` prefix for consistency
- **Network naming:** Match stack purpose (`bmpl-prod`, `bmpl-qa`, `bmpl-blog`)
- **Container naming:** Use explicit `container_name` to ensure Caddyfile works
- **Image tags:** Production always uses `:main`, QA uses configurable `${GIT_REF}`
- **Asset compilation:** Always use `RAILS_ENV=production` for `rails assets:precompile`
- **Database auth:** Using trust auth (empty password) for PostgreSQL in containers

## Maintenance

### Viewing All Containers
```bash
ssh ortiz@fenway
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
```

### Checking Logs
```bash
docker logs players-web --tail 50 --follow        # Production
docker logs players-web-qa --tail 50 --follow     # QA
docker logs caddy --tail 50 --follow              # Reverse proxy
```

### Manual Asset Rebuild (Emergency)
If you need to rebuild assets in a running container:
```bash
docker exec players-web sh -c "yarn install && yarn build && yarn build:css && RAILS_ENV=production bundle exec rails assets:precompile"
```

### Database Backup
```bash
docker exec players-db pg_dump -U postgres players_production > backup.sql
```

## Best Practices

1. **Always test in QA first** - Use separate stacks to your advantage
2. **Monitor after deployments** - Watch logs for 5-10 minutes after updates
3. **Keep edge stack stable** - Infrastructure changes affect all services
4. **Use feature branches in QA** - Test thoroughly before merging to main
5. **Asset compilation takes time** - Allow 3 minutes for containers to become healthy
6. **Check health endpoints** - Production has health checks, QA doesn't (yet)
