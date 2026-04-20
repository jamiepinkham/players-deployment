# QA Environment Stack

This is a separate QA environment that runs alongside production on fenway.

## Differences from Production

| Aspect | Production | QA |
|--------|-----------|-----|
| Container names | `players-players-1`, etc. | `players-web-qa`, etc. |
| Ports | 3000, 2368 | 3001, 2369 |
| Database volumes | `players-db-data` | `players-db-data-qa` |
| Network | `players_default` | `players_qa` |
| URL | billymartinplayersleague.com | qa.billymartinplayersleague.com |
| Branch | `main` | Any feature branch |

## Deploy QA Stack in Portainer

1. Open Portainer: http://fenway:9000
2. Stacks → Add Stack
3. Name: `fenway-apps-qa`
4. Build method: **Repository**
5. Repository URL: `https://github.com/jamiepinkham/players-deployment`
6. Repository reference: `main`
7. Compose path: `stack/docker-compose.qa.yml`
8. Add same environment variables as production
9. Deploy

## Testing Feature Branches

### Option 1: Update in Portainer UI

1. Go to `fenway-apps-qa` stack
2. Click **Editor**
3. Change image tags:
   ```yaml
   players-web-qa:
     image: ghcr.io/jamiepinkham/players:jp/consolidated-fa-improvements

   players-scheduler-qa:
     image: ghcr.io/jamiepinkham/players:jp/consolidated-fa-improvements
   ```
4. Update stack

### Option 2: Update in Git

```bash
cd ~/players-deployment
git checkout -b qa-test-new-features
vim stack/docker-compose.qa.yml  # Change image tags
git commit -am "QA: Test jp/consolidated-fa-improvements"
git push -u origin qa-test-new-features

# In Portainer, change repository reference to: qa-test-new-features
# Click "Pull and redeploy"
```

## Accessing QA

### Direct Access (via SSH tunnel)
- Players: http://fenway:3001
- Ghost: http://fenway:2369

### Via Caddy (add to Caddyfile)
```caddy
qa.billymartinplayersleague.com {
    reverse_proxy players-web-qa:3000
}
```

Then access at: https://qa.billymartinplayersleague.com

## QA Database

QA has its own **separate database volumes**, so:
- ✅ Safe to test migrations without affecting production
- ✅ Can load production data copy for realistic testing
- ✅ Can be reset/wiped anytime

### Copy Production Data to QA

```bash
# 1. Dump production database
docker exec players-db-1 pg_dump -U postgres players_production > prod_dump.sql

# 2. Restore to QA database
docker exec -i players-db-qa psql -U postgres players_production < prod_dump.sql
```

## QA Workflow

1. **Develop** → Push feature branch (e.g., `jp/new-feature`)
2. **Deploy to QA** → Update QA stack to use `jp/new-feature` branch
3. **Test** → Access via http://fenway:3001 or https://qa.billymartinplayersleague.com
4. **Iterate** → Make changes, push, redeploy QA
5. **Promote** → When ready, merge to `main`
6. **Production** → Production stack auto-pulls latest `main`

## Managing QA Stack

### View logs
```bash
docker logs -f players-web-qa
docker logs -f ghost-qa
```

### Restart QA services
```bash
docker restart players-web-qa
docker restart players-scheduler-qa
```

### Stop QA (to save resources)
In Portainer: fenway-apps-qa → Stop

Or via CLI:
```bash
cd ~/players-deployment/stack
docker-compose -f docker-compose.qa.yml down
```

### Start QA
In Portainer: fenway-apps-qa → Start

Or via CLI:
```bash
cd ~/players-deployment/stack
docker-compose -f docker-compose.qa.yml up -d
```

## Reset QA Database

If you need to start fresh:

```bash
# Stop QA stack
docker stop players-web-qa players-scheduler-qa players-db-qa

# Remove QA database volume
docker volume rm players_qa_players-db-data-qa

# Start QA stack (will create fresh database)
docker start players-db-qa players-web-qa players-scheduler-qa

# Run migrations
docker exec players-web-qa bundle exec rails db:create db:migrate
```
