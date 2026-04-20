# QA Environment Setup

## Overview

The QA environment allows you to deploy and test any branch before merging to production.

**Production**: `players.billymartinplayersleague.com` → `main` branch
**QA**: `qa.billymartinplayersleague.com` → any branch for testing

---

## Initial Setup (One-time)

### 1. Cloudflare Tunnel

Add public hostname in Cloudflare Zero Trust:

- Go to **Zero Trust** → **Networks** → **Tunnels**
- Click your tunnel → **Public Hostname** → **Add**
- Configure:
  - **Subdomain**: `qa`
  - **Domain**: `billymartinplayersleague.com`
  - **Service**: HTTP → Same as `players` subdomain (points to Caddy)

### 2. Portainer Stack

Create `bmpl-apps-qa` stack:

1. In Portainer, click **Stacks** → **Add stack**
2. Name: `bmpl-apps-qa`
3. **Web editor**: Copy contents from `stack/docker-compose.qa.yml`
4. **Environment variables**:
   ```
   GIT_REF=jp/consolidated-fa-improvements
   DATABASE_NAME=players_qa
   POSTGRES_PASSWORD=<your-password>
   SECRET_KEY_BASE=<your-secret>
   MAILGUN_SMTP_USERNAME=<username>
   MAILGUN_SMTP_PASSWORD=<password>
   ```
5. Click **Deploy the stack**

### 3. Deploy Caddyfile

SSH to fenway and update Caddy configuration:

```bash
# Copy the updated Caddyfile
cd /path/to/caddy/config
# Update with contents from caddy/Caddyfile in this repo

# Reload Caddy
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### 4. Test

Visit `https://qa.billymartinplayersleague.com`

---

## How to Test a Different Branch

### Quick Steps:

1. **Push your branch** to GitHub (if not already)
   - GitHub Actions automatically builds the Docker image

2. **Update Portainer**:
   - Go to `bmpl-apps-qa` stack
   - Click **Editor** or **Environment variables**
   - Change: `GIT_REF=your-branch-name`
   - Click **Update the stack**

3. **Test** at `qa.billymartinplayersleague.com`

### Example:

Testing the `feature/new-ui` branch:
```
GIT_REF=feature/new-ui
DATABASE_NAME=players_qa  (keep same QA database)
```

---

## Database Management

### Option A: Reuse QA Database (Recommended)

Keep `DATABASE_NAME=players_qa` - all branches share the same QA database.

**Pros**: Fast switching between branches
**Cons**: Data persists between branch switches

### Option B: Fresh Database Per Branch

Remove `DATABASE_NAME` from environment variables - auto-creates `players_<branch-name>`.

**Pros**: Isolated data per branch
**Cons**: Slower, requires database setup for each branch
**Note**: Branch names with `/` or `-` need manual name (e.g., `DATABASE_NAME=players_feature_a`)

### Option C: Copy Production Data

To test with production data:

```bash
# SSH to fenway

# Dump production database
docker exec players-db pg_dump -U postgres players_production > /tmp/prod_backup.sql

# Restore to QA database
docker exec -i players-db-qa psql -U postgres players_qa < /tmp/prod_backup.sql
```

---

## Architecture

```
Developer pushes branch
         ↓
GitHub Actions builds image → ghcr.io/jamiepinkham/players:<branch-name>
         ↓
Update GIT_REF in Portainer
         ↓
Portainer pulls new image & redeploys
         ↓
Cloudflare Tunnel → Caddy → players-web-qa:3000
         ↓
qa.billymartinplayersleague.com
```

---

## Environment Variables

### Required:

- `GIT_REF`: Git branch/tag to deploy (e.g., `main`, `feature/new-thing`)
- `SECRET_KEY_BASE`: Rails secret key
- `MAILGUN_SMTP_USERNAME`: Mailgun username
- `MAILGUN_SMTP_PASSWORD`: Mailgun password

### Optional:

- `DATABASE_NAME`: Database name (default: `players_qa`)
- `POSTGRES_PASSWORD`: Postgres password (default: trust auth)
- `RAILS_ENV`: Rails environment (default: `production`)

---

## Troubleshooting

### QA not updating after changing GIT_REF

1. Verify branch exists in GitHub
2. Check GitHub Actions completed: https://github.com/jamiepinkham/players/actions
3. Verify image exists:
   ```bash
   docker pull ghcr.io/jamiepinkham/players:<branch-name>
   ```
4. Check Portainer container logs

### Database connection errors

1. Verify `DATABASE_NAME` matches actual database
2. Check database container health: `docker ps | grep players-db-qa`
3. Check logs: `docker logs players-db-qa`

### Can't access QA subdomain

1. Verify Cloudflare Tunnel public hostname configured
2. Check Caddyfile has `qa.billymartinplayersleague.com` block
3. Verify Caddy reloaded: `docker logs caddy`
4. Check container names match: `docker ps | grep players-web-qa`

### SSL/Certificate issues

- Cloudflare Tunnel handles SSL automatically
- No Let's Encrypt needed
- Check tunnel is running and connected

---

## Files in this Repo

- `stack/docker-compose.yml` - Production stack configuration
- `stack/docker-compose.qa.yml` - QA stack configuration ⭐
- `stack/docker-compose.integration.yml` - Legacy integration (deprecated)
- `caddy/Caddyfile` - Caddy reverse proxy configuration
- `docs/QA_SETUP.md` - This file
