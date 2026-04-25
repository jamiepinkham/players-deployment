# Rollback Procedures

How to rollback the BMPL stack to a previous state.

## Application Rollback (Most Common)

Rollback to a previous version of the Rails application.

### Via Portainer (Recommended)

1. **Stacks → bmpl → Editor**
2. Find the image line:
   ```yaml
   players-web:
     image: ghcr.io/jamiepinkham/players:main
   ```
3. Change `main` to a specific tag or commit SHA:
   ```yaml
   image: ghcr.io/jamiepinkham/players:v1.2.3
   # or
   image: ghcr.io/jamiepinkham/players:sha-9332ec2b
   ```
4. Do the same for `players-sidekiq` and `players-scheduler`
5. Check **Re-pull images and redeploy**
6. Click **Update the stack**

### Via SSH

```bash
ssh ortiz@fenway

# Pull specific version
docker pull ghcr.io/jamiepinkham/players:TAG_NAME

# Tag it as the version we want to run
docker tag ghcr.io/jamiepinkham/players:TAG_NAME ghcr.io/jamiepinkham/players:main

# Restart services
docker restart players-web players-sidekiq players-scheduler
```

### Finding Previous Versions

**GitHub Tags:**
```bash
gh api repos/jamiepinkham/players/tags --jq '.[].name' | head -10
```

**Or browse:** https://github.com/jamiepinkham/players/tags

**GitHub Container Registry:**
https://github.com/jamiepinkham/players/pkgs/container/players

## Database Rollback

### Rollback Migrations

If a migration caused issues:

```bash
ssh ortiz@fenway

# Rollback last migration
docker exec players-web bundle exec rails db:rollback

# Rollback multiple migrations
docker exec players-web bundle exec rails db:rollback STEP=3

# Check migration status
docker exec players-web bundle exec rails db:migrate:status
```

### Restore from Backup

If you need to restore the entire database:

```bash
ssh ortiz@fenway

# List available backups
ls -lh /tmp/*.sql

# Stop services to prevent connections
docker stop players-web players-sidekiq players-scheduler

# Restore database
docker exec -i players-db psql -U postgres players_production < /tmp/players_backup_YYYYMMDD.sql

# Restart services
docker start players-web players-sidekiq players-scheduler

# Verify
docker exec players-db psql -U postgres players_production -c "SELECT COUNT(*) FROM users;"
```

## QA Rollback

Rollback QA to a different branch:

**Via Portainer:**
1. Stacks → bmpl → Editor
2. Environment variables → Find `GIT_REF`
3. Change to previous branch/tag
4. Update the stack

**Via SSH:**
```bash
docker pull ghcr.io/jamiepinkham/players:BRANCH_NAME
docker tag ghcr.io/jamiepinkham/players:BRANCH_NAME ghcr.io/jamiepinkham/players:GIT_REF_VALUE
docker restart players-web-qa players-sidekiq-qa players-scheduler-qa
```

## Ghost Rollback

Rollback Ghost to previous version:

**Via Portainer:**
1. Stacks → bmpl → Editor
2. Find Ghost service:
   ```yaml
   ghost:
     image: ghost:latest
   ```
3. Change to specific version:
   ```yaml
   ghost:
     image: ghost:5.87.0
   ```
4. Update the stack

**Ghost versions:** https://hub.docker.com/_/ghost/tags

## Full Stack Rollback

If everything is broken and you need to rollback the entire stack:

### Option 1: Revert to Previous Compose File

If you have the previous `docker-compose.consolidated.yml`:

1. Portainer → bmpl → Editor
2. Paste previous compose file
3. Update the stack

### Option 2: Restore from Git

```bash
# On your local machine
cd ~/dev/players-deployment
git log --oneline  # Find commit before the problematic change
git show COMMIT_HASH:stack/docker-compose.consolidated.yml

# Copy that version to Portainer
```

## Emergency Rollback (Site Down)

If the site is completely down:

### 1. Check What's Running

```bash
ssh ortiz@fenway
docker ps
docker logs players-web --tail 50
docker logs ghost --tail 50
```

### 2. Quick Restart

Often just restarting fixes it:

```bash
docker restart players-web
docker restart ghost

# Or restart everything:
docker restart $(docker ps -q)
```

### 3. Rollback Application

Use the Application Rollback steps above to go back to `main` or a known-good tag.

### 4. Check Database

```bash
# Verify database is accessible
docker exec players-db psql -U postgres players_production -c "SELECT 1;"

# Check for locks
docker exec players-db psql -U postgres players_production -c "SELECT * FROM pg_locks WHERE NOT granted;"
```

## Rollback Checklist

After any rollback:

- [ ] Site is accessible
- [ ] Users can log in
- [ ] Database queries work
- [ ] No errors in logs
- [ ] Background jobs processing
- [ ] Ghost blog accessible (if rolled back)
- [ ] Document what went wrong
- [ ] Consider hotfix vs full rollback

## Prevention

To make rollbacks easier:

1. **Always backup before major changes**
   ```bash
   docker exec players-db pg_dumpall -U postgres > /tmp/pre_deploy_$(date +%Y%m%d).sql
   ```

2. **Use git tags for releases**
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

3. **Test in QA first**
   - Deploy to QA
   - Test thoroughly
   - Then deploy to production

4. **Keep previous backups**
   ```bash
   # Don't delete old backups immediately
   ls -lt /tmp/*.sql | head -10
   ```

## Recovery Time Objectives

Expected recovery times:

| Rollback Type | Expected Time |
|--------------|---------------|
| Application version | 2-5 minutes |
| Database migration | 5-10 minutes |
| Database restore | 10-20 minutes |
| Full stack rollback | 5-10 minutes |

## Support

If rollback doesn't work:
- Check `docs/DEPLOYMENT.md` for troubleshooting
- Review logs: `docker logs <container> --tail 100`
- Verify backups exist: `ls -lh /tmp/*.sql`
