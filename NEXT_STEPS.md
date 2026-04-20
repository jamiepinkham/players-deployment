# Next Steps: Deploying to Fenway

The players-deployment repository is now complete and pushed to GitHub! Here's what to do next.

## ✅ Completed

1. ✅ Created unified Portainer stack (players + ghost)
2. ✅ Extracted configuration from running fenway containers
3. ✅ Configured proper networks (web + players_default)
4. ✅ Set up centralized environment variables
5. ✅ Created Caddyfile for billymartinplayersleague.com
6. ✅ Created deployment and rollback documentation
7. ✅ Pushed to GitHub: https://github.com/jamiepinkham/players-deployment

## 📋 Ready to Deploy

### Option 1: Deploy via Portainer UI (Recommended)

1. **Open Portainer** on fenway: http://fenway:9000

2. **Create Stack**:
   - Go to Stacks → Add Stack
   - Name: `bmpl-apps`
   - Build method: **Repository**
   - Repository URL: `https://github.com/jamiepinkham/players-deployment`
   - Repository reference: `main`
   - Compose path: `stack/docker-compose.yml`

3. **Add Environment Variables**:
   Click "Add environment variable" and add these:
   - `POSTGRES_PASSWORD` = (current PostgreSQL password)
   - `SECRET_KEY_BASE` = (current Rails secret from running container)
   - `MAILGUN_SMTP_USERNAME` = `postmaster@mail.billymartinplayersleague.com`
   - `MAILGUN_SMTP_PASSWORD` = (current Mailgun password)
   - `GHOST_DB_PASSWORD` = (current Ghost MySQL password from running container)

4. **Deploy** the stack

5. **Update Caddy** to point to the new container (if needed)

### Option 2: Deploy via Docker Compose Directly

```bash
# 1. SSH to fenway
ssh ortiz@fenway

# 2. Clone the repo
cd ~
git clone https://github.com/jamiepinkham/players-deployment.git
cd players-deployment/stack

# 3. Create .env file
cp .env.template .env
vim .env
# Fill in all the CHANGE_ME values

# 4. Create external web network (if it doesn't exist)
docker network create web 2>/dev/null || true

# 5. Deploy
docker-compose up -d

# 6. Verify
docker ps
docker-compose logs -f
```

## 🔧 Migration from Current Setup

### Before Switching

1. **Backup current databases**:
   ```bash
   docker exec players-db-1 pg_dump -U postgres players_production > players_backup_$(date +%Y%m%d).sql
   docker exec ghost-db mysqldump -u ghost -pPASSWORD ghost > ghost_backup_$(date +%Y%m%d).sql
   ```

2. **Note current environment variables**:
   ```bash
   # Get current values you'll need
   docker exec players-players-1 env | grep SECRET_KEY_BASE
   docker exec players-players-1 env | grep MAILGUN
   docker exec ghost env | grep database__connection__password
   ```

### Switching to New Stack

If you're replacing the existing stacks:

1. **Stop old stacks** (via Portainer or docker-compose)
2. **Deploy new unified stack** (see options above)
3. **Verify everything works**
4. **Remove old stacks** once verified

### Zero-Downtime Approach

For zero downtime:

1. Deploy new stack **without removing old stack**
2. Test new stack at http://fenway:3000 and verify database connections
3. Update Caddy to point to new containers
4. Monitor for issues
5. Remove old stack once stable

## 📝 Environment Variables You'll Need

Get these from your current running containers:

```bash
# SECRET_KEY_BASE
docker exec players-players-1 env | grep SECRET_KEY_BASE

# POSTGRES_PASSWORD
# Check current .env file or Portainer environment variables

# MAILGUN credentials
docker exec players-players-1 env | grep MAILGUN

# GHOST_DB_PASSWORD
docker exec ghost env | grep database__connection__password
```

## 🔍 Verification Checklist

After deployment:

- [ ] All 5 containers running: `docker ps`
- [ ] Players database healthy: `docker inspect players-db-1 | grep Health`
- [ ] Ghost database healthy: `docker inspect ghost-db | grep Health`
- [ ] Players app accessible: `curl http://localhost:3000`
- [ ] No errors in logs: `docker-compose logs --tail=100`
- [ ] Caddy can reach containers on web network
- [ ] Site accessible via billymartinplayersleague.com

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Full deployment procedures
- [Rollback Guide](docs/ROLLBACK.md) - How to rollback if needed
- [Stack README](stack/README.md) - Stack architecture details
- [System Info](docs/SYSTEM_INFO.md) - Extracted fenway system information

## 🆘 Troubleshooting

If containers won't start:

```bash
# Check logs
docker-compose logs players-web
docker-compose logs ghost

# Verify environment variables are set
docker-compose config

# Check network exists
docker network ls | grep web
```

If database connection fails:

```bash
# Test PostgreSQL
docker exec -it players-db-1 psql -U postgres -d players_production -c "SELECT 1;"

# Test MySQL
docker exec -it ghost-db mysql -u ghost -p ghost -e "SELECT 1;"
```

## 🎯 What Changed

This unified stack solves the three original problems:

1. **Caddy config in source control** ✅
   - `caddy/Caddyfile` is now tracked in git

2. **Centralized credentials** ✅
   - Single `.env` file with all secrets
   - Shared across all containers via environment variables

3. **Mailgun credentials shared** ✅
   - Both players and ghost use same `MAILGUN_SMTP_*` variables
   - No more duplication

## 📞 Need Help?

- Check [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed procedures
- Check [docs/ROLLBACK.md](docs/ROLLBACK.md) if something goes wrong
- Review extracted config in `docs/original-configs/` to see current setup
