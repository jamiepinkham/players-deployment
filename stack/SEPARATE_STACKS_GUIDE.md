# Separate Stacks Deployment Guide

This guide explains how to deploy the BMPL infrastructure using separate stacks instead of the consolidated approach.

## Architecture

The platform is split into 4 independent stacks:

1. **`bmpl-edge`** - Caddy reverse proxy + Cloudflare tunnel
2. **`bmpl-players-prod`** - Production Rails app
3. **`bmpl-players-qa`** - QA/Staging Rails app
4. **`bmpl-blog`** - League website/blog (Ghost CMS)

## Benefits

✅ **Independent deployments** - Update QA without touching production
✅ **Isolated failures** - Issues in one stack don't affect others
✅ **Clear separation** - Edge vs applications
✅ **Easier rollbacks** - Roll back individual stacks
✅ **Better resource management** - Restart only what you need

## Prerequisites - Create External Networks

Before deploying ANY stacks, create the shared networks:

```bash
ssh ortiz@fenway

# Create shared networks
docker network create web
docker network create players_default
docker network create players_qa
docker network create ghost_default
```

**Note:** If networks already exist from the consolidated stack, you can skip this step.

## Migration from Consolidated Stack

If you're currently running `docker-compose.consolidated.yml`, follow these steps:

### Step 1: Stop the Consolidated Stack

In Portainer:
1. Go to **Stacks → bmpl**
2. Click **Stop**
3. **DO NOT DELETE** - We need to preserve volumes and networks

### Step 2: Verify Networks Exist

```bash
ssh ortiz@fenway
docker network ls | grep -E "web|players|ghost"
```

You should see:
- `web`
- `players_default`
- `players_qa`
- `ghost_default` (if not, create it: `docker network create ghost_default`)

### Step 3: Deploy Stacks in Order

Deploy in Portainer using these stack files:

#### 1. Edge (FIRST)
- **Stack name:** `bmpl-edge`
- **File:** `bmpl-edge.yml`
- **Why first:** Caddy must be running before apps start

#### 2. Blog (Ghost)
- **Stack name:** `bmpl-blog`
- **File:** `bmpl-blog.yml`
- **Can deploy:** Anytime after infrastructure

#### 3. Production
- **Stack name:** `bmpl-players-prod`
- **File:** `bmpl-players-prod.yml`
- **Can deploy:** Anytime after infrastructure

#### 4. QA
- **Stack name:** `bmpl-players-qa`
- **File:** `bmpl-players-qa.yml`
- **Can deploy:** Anytime after infrastructure

### Step 4: Verify All Services

```bash
ssh ortiz@fenway
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
```

You should see all containers running and connected to the correct networks.

### Step 5: Test Endpoints

- **Production:** https://players.billymartinplayersleague.com
- **QA:** https://qa.billymartinplayersleague.com
- **Ghost:** https://billymartinplayersleague.com

### Step 6: Remove Old Consolidated Stack

Once everything is working:

In Portainer:
1. Go to **Stacks → bmpl** (if it still exists)
2. Click **Remove**
3. ⚠️ **UNCHECK "Remove associated volumes"** - We're using the same volumes!

## Deployment in Portainer

### Creating a New Stack

1. Go to **Stacks → Add stack**
2. Enter stack name (e.g., `bmpl-edge`)
3. Choose **Upload** or **Web editor**
4. Paste the stack YAML content
5. Add environment variables (use corresponding `.env` file)
6. Click **Deploy the stack**

### Environment Variables Needed

Each stack has its own `.env` file:

- **Edge:** `.env.edge`
- **Production:** `.env.production`
- **QA:** `.env.qa`
- **Ghost:** `.env.ghost`

When deploying in Portainer, you can either:
1. **Load from file** - Upload the corresponding `.env` file
2. **Copy/paste** - Paste the contents into Portainer's environment variables section

**Important:** Keep these files secure - they contain credentials!

## Updating Individual Stacks

### Update QA Only
1. Go to **Stacks → bmpl-players-qa → Editor**
2. Check **"Re-pull images and redeploy"**
3. Change `GIT_REF` if needed (e.g., `GIT_REF=my-feature-branch`)
4. Click **"Update the stack"**
5. ✅ Production stays running!

### Update Production Only
1. Go to **Stacks → bmpl-players-prod → Editor**
2. Check **"Re-pull images and redeploy"**
3. Click **"Update the stack"**
4. ✅ QA stays running!

### Update Edge
1. Go to **Stacks → bmpl-edge → Editor**
2. Modify Caddyfile if needed
3. Click **"Update the stack"**
4. ⚠️ Brief interruption to all traffic (Caddy restarts)

### Update Blog (Ghost)
1. Go to **Stacks → bmpl-blog → Editor**
2. Check **"Re-pull images and redeploy"**
3. Click **"Update the stack"**
4. ✅ Players apps stay running!

## Network Communication

All stacks communicate via the shared `web` network:

```
Cloudflare Tunnel → Caddy (web network) → Players/Ghost containers (web network)
```

Internal stack networks:
- `players_default` - Production database/redis communication
- `players_qa` - QA database/redis communication
- `ghost_default` - Ghost database communication

## Troubleshooting

### Container can't reach another container
- Verify both containers are on the same network
- Check `docker network inspect web` to see connected containers

### Caddy shows "502 Bad Gateway"
- Check if target container is running: `docker ps | grep players-web`
- Verify container is on `web` network
- Check container name matches Caddyfile (e.g., `players-web`, not `players-web-1`)

### Network already exists error
- Good! Use the existing network
- Verify it's external in the stack YAML: `external: true`

### Need to see all containers across stacks
```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -E "players|ghost|caddy|cloudflared"
```

## Rollback Procedure

If a stack update causes issues:

1. Go to **Stacks → [stack-name] → Editor**
2. Change image tag to previous version OR revert code changes
3. Check **"Re-pull images and redeploy"**
4. Click **"Update the stack"**

Example - rollback QA to main:
```yaml
image: ghcr.io/jamiepinkham/players:main  # Instead of feature branch
```

## Best Practices

1. **Always deploy infrastructure first** - Other stacks depend on it
2. **Test in QA before production** - Use separate stacks to your advantage
3. **Update QA frequently** - It's independent, safe to experiment
4. **Update production cautiously** - Schedule during low-traffic windows
5. **Keep Caddyfile in sync** - If you add new routes, update infrastructure stack
6. **Monitor logs after updates** - `docker logs -f <container-name>`

## Files Reference

### Stack Files
- `bmpl-edge.yml` - Caddy + Cloudflare
- `bmpl-players-prod.yml` - Production players app
- `bmpl-players-qa.yml` - QA players app
- `bmpl-blog.yml` - Ghost blog

### Environment Files
- `.env.edge` - Edge stack variables
- `.env.production` - Production stack variables
- `.env.qa` - QA stack variables
- `.env.ghost` - Ghost/blog stack variables
- `.env.fenway` - Legacy file (replaced by separate files above)
