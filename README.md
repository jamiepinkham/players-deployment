# BMPL Deployment

Infrastructure documentation and stack definitions for the Billy Martin Players League platform.

## Quick Start

The platform runs on **5 separate Docker Compose stacks** deployed via Portainer on fenway.

**📖 Read the docs:**
- **[stack/ARCHITECTURE.md](stack/ARCHITECTURE.md)** - Complete architecture reference
- **[stack/SEPARATE_STACKS_GUIDE.md](stack/SEPARATE_STACKS_GUIDE.md)** - Deployment guide

## Stack Files

Located in `stack/`:
- **bmpl-edge.yml** - Caddy reverse proxy + Cloudflare tunnel
- **bmpl-players-prod.yml** - Production Rails application
- **bmpl-players-qa.yml** - QA/Staging Rails application
- **bmpl-stats.yml** - Shared stats API microservice (used by both prod and QA)
- **bmpl-blog.yml** - Ghost CMS for league website

## Environment Files

Each stack has a corresponding `.env.*` file (gitignored):
- `.env.fenway` - Server-level configuration (shared across stacks)
- `.env.edge` - Cloudflare tunnel token
- `.env.production` - Production secrets (Rails, DB, Mailgun)
- `.env.qa` - QA secrets + `GIT_REF` for branch deployment
- `.env.blog` - Ghost/MySQL credentials

See `.env.template` for structure.

## URLs

- **Production:** https://players.billymartinplayersleague.com
- **QA:** https://qa.billymartinplayersleague.com
- **Blog:** https://billymartinplayersleague.com

## Additional Docs

- **[docs/CLOUDFLARE.md](docs/CLOUDFLARE.md)** - Cloudflare tunnel setup
- **[docs/MANUAL_QA_SYNC.md](docs/MANUAL_QA_SYNC.md)** - Sync production data to QA

## Scripts

- `scripts/sync-prod-to-qa.sh` - Database sync for QA testing
- `scripts/export-qa-env.sh` - Export QA environment variables
- `scripts/update-caddy.sh` - Update Caddy configuration
