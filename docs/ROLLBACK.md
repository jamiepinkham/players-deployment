# Rollback Procedures

This guide covers how to rollback the fenway stack to a previous state.

## Quick Rollback (Image-Based)

If you need to rollback to a previous version of the Players app:

### 1. Find Previous Image Tag

```bash
# List available tags
gh api repos/jamiepinkham/players/tags --paginate --jq '.[].name'

# Or check GitHub directly
# https://github.com/jamiepinkham/players/tags
```

### 2. Update docker-compose.yml

Edit `stack/docker-compose.yml` and change the image tags:

```yaml
players-web:
  image: ghcr.io/jamiepinkham/players:TAG_NAME  # Change to specific tag

players-scheduler:
  image: ghcr.io/jamiepinkham/players:TAG_NAME  # Same tag
```

### 3. Redeploy

```bash
cd ~/players-deployment/stack
docker-compose pull
docker-compose up -d
```

## Database Rollback

If you need to rollback a database migration:

### Players Database

```bash
# SSH to fenway
ssh ortiz@fenway

# Rollback last migration
docker exec -it players-players-1 bundle exec rails db:rollback

# Rollback multiple migrations
docker exec -it players-players-1 bundle exec rails db:rollback STEP=3

# Rollback to specific version
docker exec -it players-players-1 bundle exec rails db:migrate:down VERSION=20260419123456
```

### Ghost Database

Ghost doesn't support rollback. You'll need to restore from backup.

## Full Stack Rollback from Backup

### 1. Stop Running Stack

```bash
cd ~/players-deployment/stack
docker-compose down
```

### 2. Restore Database Backups

#### Players Database

```bash
# Copy backup to server
scp players_backup_TIMESTAMP.sql ortiz@fenway:~/

# Restore
docker-compose up -d players-db
docker exec -i players-db-1 psql -U postgres players_production < ~/players_backup_TIMESTAMP.sql
```

#### Ghost Database

```bash
# Copy backup to server
scp ghost_backup_TIMESTAMP.sql ortiz@fenway:~/

# Restore
docker-compose up -d ghost-db
docker exec -i ghost-db mysql -u ghost -p ghost < ~/ghost_backup_TIMESTAMP.sql
```

### 3. Restore Volume Data (if needed)

If you have volume backups:

```bash
# Stop everything
docker-compose down

# Remove volumes
docker volume rm players_default_players-db-data
docker volume rm players_default_ghost-db-data
docker volume rm players_default_ghost-content

# Restore from tar backups
docker run --rm -v players_default_players-db-data:/data -v ~/backups:/backup alpine sh -c "cd /data && tar xzf /backup/players-db-data.tar.gz"
docker run --rm -v players_default_ghost-db-data:/data -v ~/backups:/backup alpine sh -c "cd /data && tar xzf /backup/ghost-db-data.tar.gz"
docker run --rm -v players_default_ghost-content:/data -v ~/backups:/backup alpine sh -c "cd /data && tar xzf /backup/ghost-content.tar.gz"

# Start stack
docker-compose up -d
```

### 4. Verify

```bash
# Check containers are running
docker ps

# Check logs for errors
docker-compose logs -f

# Test applications
curl http://localhost:3000
```

## Emergency Stop

If something goes wrong and you need to stop everything immediately:

```bash
cd ~/players-deployment/stack
docker-compose down
```

This stops all containers but preserves volumes (data is safe).

## Rollback Deployment Configuration

If you need to revert changes to docker-compose.yml or environment variables:

```bash
cd ~/players-deployment
git log  # Find previous commit
git checkout <commit-hash> stack/docker-compose.yml
docker-compose up -d
```

## Common Rollback Scenarios

### After Failed Migration

```bash
# 1. Stop the web container
docker stop players-players-1

# 2. Rollback migration
docker exec -it players-players-1 bundle exec rails db:rollback

# 3. Deploy previous code version
# (see Image-Based Rollback above)

# 4. Start container
docker start players-players-1
```

### After Config Change Breaks Site

```bash
# 1. Revert .env changes
cd ~/players-deployment/stack
git checkout HEAD -- .env

# 2. Or edit manually
vim .env

# 3. Recreate containers
docker-compose up -d --force-recreate
```

### After Ghost Update Breaks Blog

```bash
# 1. Pin to previous version
vim stack/docker-compose.yml
# Change ghost:latest to ghost:5.x.x (specific version)

# 2. Redeploy
docker-compose pull ghost
docker-compose up -d ghost
```

## Prevention

### Pin Image Versions

Instead of using `:latest` or `:main`, pin to specific versions:

```yaml
players-web:
  image: ghcr.io/jamiepinkham/players:v1.2.3

ghost:
  image: ghost:5.96.0
```

### Backup Before Changes

Always backup before making changes:

```bash
# Backup databases
docker exec players-db-1 pg_dump -U postgres players_production > backup_$(date +%Y%m%d_%H%M%S).sql
docker exec ghost-db mysqldump -u ghost -p ghost > ghost_backup_$(date +%Y%m%d_%H%M%S).sql

# Tag current state in git
git tag -a "pre-deploy-$(date +%Y%m%d-%H%M%S)" -m "Before deployment"
git push --tags
```
