# Cloudflare Configuration

Complete Cloudflare setup for the BMPL infrastructure.

## Overview

Cloudflare provides:
- **DNS management** for all three domains
- **SSL/TLS encryption** (automatic)
- **DDoS protection** and WAF
- **Cloudflare Tunnel** (replaces port forwarding/public IP)

## Architecture

```
User Browser
  ↓
Cloudflare Edge (SSL termination, caching, protection)
  ↓
Cloudflare Tunnel (encrypted tunnel to fenway)
  ↓
cloudflared container (tunnel endpoint on fenway)
  ↓
Caddy reverse proxy (HTTP routing by hostname)
  ↓
Application containers (players-web, ghost, etc.)
```

## DNS Configuration

**Dashboard:** Cloudflare → billymartinplayersleague.com → DNS

### Current DNS Records

| Name | Type | Content | Proxy | Notes |
|------|------|---------|-------|-------|
| `@` | CNAME | UUID.cfargotunnel.com | ✓ Proxied | Root domain (billymartinplayersleague.com) |
| `players` | CNAME | UUID.cfargotunnel.com | ✓ Proxied | players.billymartinplayersleague.com |
| `qa` | CNAME | UUID.cfargotunnel.com | ✓ Proxied | qa.billymartinplayersleague.com |

**Important:**
- All three point to the same Cloudflare Tunnel
- All are **Proxied** (orange cloud) for protection
- Caddy does the hostname-based routing

### Finding Your Tunnel ID

The CNAME target format: `<UUID>.cfargotunnel.com`

To find your UUID:
1. Cloudflare → Zero Trust → Networks → Tunnels
2. Find your tunnel → Configuration
3. The UUID is in the tunnel details

## Cloudflare Tunnel Setup

**Dashboard:** Cloudflare → Zero Trust → Networks → Tunnels

### Current Tunnel Configuration

**Tunnel Name:** (your tunnel name)

**Connector:** Running as `cloudflared` container in the `bmpl` stack

**Public Hostnames:**

| Hostname | Service | Notes |
|----------|---------|-------|
| players.billymartinplayersleague.com | http://caddy:80 | Production Rails app |
| qa.billymartinplayersleague.com | http://caddy:80 | QA Rails app |
| billymartinplayersleague.com | http://caddy:80 | Ghost blog |

All three route to Caddy because:
- Caddy inspects the `Host` header
- Routes requests based on domain name
- See `caddy/Caddyfile` for routing rules

### Tunnel Token

The tunnel token is stored in `CLOUDFLARE_TUNNEL_TOKEN` environment variable.

**To get the token:**
1. Cloudflare → Zero Trust → Networks → Tunnels
2. Click your tunnel → Configure
3. Under "Install and run a connector", select "Docker"
4. Copy the token from the docker run command

**Token format:** Starts with `eyJh...` (it's a JWT)

**DO NOT commit this token to git!** It's in `.env.fenway` which is gitignored.

### Recreating the Tunnel

If you need to create a new tunnel:

1. **Create Tunnel:**
   - Cloudflare → Zero Trust → Networks → Tunnels
   - Create a tunnel
   - Give it a name (e.g., `bmpl-fenway`)
   - Choose "Docker" as connector type
   - Copy the token

2. **Configure Public Hostnames:**
   - Add public hostname: `players.billymartinplayersleague.com`
   - Service: `http://caddy:80`
   - Repeat for `qa.billymartinplayersleague.com` and `billymartinplayersleague.com`

3. **Update DNS:**
   - Cloudflare → DNS
   - Update/create CNAME records pointing to `<UUID>.cfargotunnel.com`

4. **Update Stack:**
   - Portainer → bmpl → Environment variables
   - Update `CLOUDFLARE_TUNNEL_TOKEN` with new token
   - Update the stack

## SSL/TLS Settings

**Dashboard:** Cloudflare → billymartinplayersleague.com → SSL/TLS

**Current settings:**
- **SSL/TLS encryption mode:** Full (strict)
- **Edge Certificates:** Automatic
- **Always Use HTTPS:** On
- **Minimum TLS Version:** 1.2

**Why "Full (strict)"?**
- Cloudflare → Tunnel uses encrypted connection
- Tunnel → Caddy uses HTTP (internal network, no encryption needed)
- Caddy doesn't need SSL certs (Cloudflare handles it)

## Security Settings

**Dashboard:** Cloudflare → billymartinplayersleague.com → Security

**Current settings:**
- **Security Level:** Medium
- **Bot Fight Mode:** On (if available)
- **Browser Integrity Check:** On

**Rate Limiting:** Not configured (Ghost has its own rate limiting)

## Firewall Rules

**Dashboard:** Cloudflare → billymartinplayersleague.com → Security → WAF

Currently no custom rules. Cloudflare's automatic protection is active.

**Potential rules to add:**
- Block countries you don't expect traffic from
- Rate limit /ghost/api/ endpoints
- Challenge traffic to /ghost/ghost/ (admin area)

## Caching

**Dashboard:** Cloudflare → billymartinplayersleague.com → Caching

**Current settings:**
- **Caching Level:** Standard
- **Browser Cache TTL:** Respect Existing Headers

Cloudflare caches static assets automatically. Dynamic content (HTML pages) typically passes through.

## Page Rules

**Dashboard:** Cloudflare → billymartinplayersleague.com → Rules → Page Rules

Currently no custom page rules.

**Potential page rules:**
- Cache everything on `/assets/*` (Rails assets)
- Bypass cache on `/ghost/api/*` (Ghost API)

## Monitoring

### Checking Tunnel Status

**Via Cloudflare:**
- Zero Trust → Networks → Tunnels
- Your tunnel should show "Healthy" with green dot

**Via Container:**
```bash
ssh ortiz@fenway
docker logs cloudflared --tail 50

# Should see: "Connection ... registered"
# Should NOT see: "failed to connect" or "authentication failed"
```

### Analytics

**Dashboard:** Cloudflare → billymartinplayersleague.com → Analytics

View:
- Traffic volume
- Threats blocked
- Bandwidth saved by caching

## Troubleshooting

### Tunnel Connection Issues

**Symptoms:** Sites unreachable, "502 Bad Gateway"

**Check:**
```bash
# Is cloudflared running?
docker ps | grep cloudflared

# Check logs
docker logs cloudflared --tail 50

# Restart tunnel
docker restart cloudflared
```

**Cloudflare Dashboard:**
- Zero Trust → Tunnels → Check if tunnel shows "Healthy"

### DNS Propagation

After DNS changes:
```bash
# Check DNS resolution
dig players.billymartinplayersleague.com
dig billymartinplayersleague.com

# Should show CNAME to cfargotunnel.com
```

### SSL Certificate Errors

**Symptoms:** Browser shows "Your connection is not private"

**Cause:** Usually Cloudflare SSL mode mismatch

**Fix:**
- Cloudflare → SSL/TLS → Set to "Full (strict)"
- Wait 5-10 minutes for changes to propagate

### 521 Error (Web Server is Down)

**Cause:** Caddy or application containers are down

**Check:**
```bash
docker ps | grep -E "(caddy|players-web|ghost)"
docker logs caddy --tail 50
```

## Backup Configuration

Your tunnel configuration is stored in Cloudflare. To document:

1. **Export tunnel config:**
   - Zero Trust → Tunnels → Your tunnel → Configure
   - Screenshot or document public hostnames

2. **Save tunnel token:**
   - Keep `.env.fenway` backed up securely (1Password, encrypted file, etc.)

3. **DNS records:**
   - Cloudflare → DNS → Export DNS records (if available)

## Recreation Checklist

If you need to rebuild from scratch:

- [ ] Create Cloudflare Tunnel in Zero Trust
- [ ] Configure public hostnames (players, qa, root domain)
- [ ] Copy tunnel token
- [ ] Update DNS CNAME records
- [ ] Update `CLOUDFLARE_TUNNEL_TOKEN` in Portainer
- [ ] Restart cloudflared container
- [ ] Verify tunnel shows "Healthy"
- [ ] Test all three URLs

## Additional Resources

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Zero Trust Dashboard](https://one.dash.cloudflare.com/)
- [DNS Dashboard](https://dash.cloudflare.com/)
