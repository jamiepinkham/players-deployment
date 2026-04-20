# Caddy Configuration

This directory contains the Caddy reverse proxy configuration for fenway.

## Files

- `Caddyfile` - Main Caddy configuration (extracted from fenway)

## Location on Server

The Caddyfile should be deployed to `/etc/caddy/Caddyfile` on fenway.

## Reloading Configuration

After updating the Caddyfile on the server:

```bash
sudo systemctl reload caddy
```

Or if using Docker:

```bash
docker restart caddy
```

## Common Configuration

The Caddyfile typically handles:
- HTTPS/TLS termination
- Reverse proxy to players app (port 3000)
- Reverse proxy to ghost blog (port 2368)
- Static file serving
- Redirects and URL rewriting
