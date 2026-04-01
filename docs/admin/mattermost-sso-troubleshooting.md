# Mattermost Entra ID SSO — Troubleshooting Log

**Document Type:** Technical Troubleshooting Log  
**Author:** Will Chang, IT Operations Engineer  
**Audience:** TinyCo IT Administrator  
**Last Updated:** March 2026  
**Status:** In Progress — SSO not yet fully resolved  

---

## Overview

This document is a complete chronological log of every attempt made to 
configure Entra ID SSO for Mattermost. It serves both as a troubleshooting 
reference and as an honest account of the challenges encountered during 
self-hosted Mattermost SSO configuration.

**Environment:**
- Mattermost Team Edition 11.5.1 (Enterprise trial license active)
- Ubuntu 24.04 on Azure VM (Standard B2s — 2 vCPU, 4GB RAM)
- Public IP: `20.63.73.34`
- Tailscale IP: `100.83.194.101`
- Tailscale hostname: `tinyco-vm.tail7ee901.ts.net`
- Entra tenant: `TinyCoDDG.onmicrosoft.com`
- Mattermost app registration: `TinyCo-Mattermost`

---

## Root Cause Summary

Mattermost's OAuth/OpenID flow requires SSL to be terminated **directly 
on Mattermost itself** — not on a reverse proxy. When SSL is handled by 
Nginx and Mattermost runs plain HTTP internally, Mattermost detects the 
absence of SSL and blocks the OAuth flow with:
```
Office365/OpenID SSO through OAuth 2.0 not available on this server.
```

This is a known Mattermost limitation that affects all self-hosted 
deployments using a reverse proxy for SSL termination.

---

## Attempt 1 — Initial Redirect URI (HTTP)

**Date:** March 30, 2026

**What we tried:**
Configured Mattermost OpenID Connect settings via System Console with 
redirect URI pointing to the public IP:
```
http://20.63.73.34:8065/signup/openid/complete
```

**Error:**
Entra ID refused to save the redirect URI — Microsoft only accepts 
HTTPS redirect URIs for OAuth/OpenID applications.
```
Redirect URI is not valid. Only HTTPS redirect URIs are accepted.
```

**Why it failed:**
Microsoft enforces HTTPS on all OAuth redirect URIs as a security 
requirement. HTTP URIs are rejected regardless of environment.

**Lesson learned:**
Any Mattermost deployment using Entra ID SSO must be accessible via 
HTTPS — plain HTTP is not an option with Microsoft identity providers.

---

## Attempt 2 — Tailscale Hostname as Redirect URI

**What we tried:**
Used the Tailscale MagicDNS hostname as the redirect URI since Tailscale 
provides HTTPS-style hostnames:
```
https://tinyco-vm.tail7ee901.ts.net:8065/signup/openid/complete
```

Updated Mattermost `docker-compose.yml`:
```yaml
MM_SERVICESETTINGS_SITEURL: https://tinyco-vm.tail7ee901.ts.net:8065
```

Restarted containers:
```bash
sudo docker-compose down
sudo docker-compose up -d
```

**Error:**
```
Office365 SSO through OAuth 2.0 not available on this server.
```

**Why it failed:**
Mattermost was still running plain HTTP internally on port 8065. The 
Tailscale hostname resolves to the VM but Mattermost has no SSL 
certificate — it detects HTTP and blocks OAuth.

Additionally, Tailscale HTTPS certificates (which would have solved this) 
require the Enterprise plan, not Premium:
```
500 Internal Server Error: your Tailscale account does not support 
getting TLS certs
```

**Lesson learned:**
Tailscale hostnames provide DNS resolution but not automatic SSL 
termination. SSL certificates must be separately provisioned.

---

## Attempt 3 — Nginx Reverse Proxy with Self-Signed Certificate

**What we tried:**
Installed Nginx as a reverse proxy to handle HTTPS termination in front 
of Mattermost.

**Step 1 — Install Nginx:**
```bash
sudo apt-get install -y nginx
```

**Step 2 — Generate self-signed SSL certificate:**
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/mattermost.key \
  -out /etc/ssl/certs/mattermost.crt \
  -subj "/CN=tinyco-vm.tail7ee901.ts.net"
```

**Step 3 — Create Nginx config:**
```bash
sudo nano /etc/nginx/sites-available/mattermost
```
```nginx
server {
    listen 443 ssl;
    server_name tinyco-vm.tail7ee901.ts.net;

    ssl_certificate /etc/ssl/certs/mattermost.crt;
    ssl_certificate_key /etc/ssl/private/mattermost.key;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

**Step 4 — Enable and start Nginx:**
```bash
sudo ln -s /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**Step 5 — Open port 443 in Azure:**
Added inbound port rule in Azure portal:
- Port: 443
- Protocol: TCP
- Priority: 320
- Name: Allow-HTTPS-443

**Step 6 — Update Mattermost Site URL:**
```yaml
MM_SERVICESETTINGS_SITEURL: https://tinyco-vm.tail7ee901.ts.net
```

**Step 7 — Update Entra redirect URI:**
```
https://tinyco-vm.tail7ee901.ts.net/signup/openid/complete
```

**Error:**
```
Office365 SSO through OAuth 2.0 not available on this server.
```

**Why it failed:**
Mattermost detects SSL at the application layer, not at the network 
layer. Even though Nginx is serving HTTPS externally, Mattermost itself 
is still running HTTP internally. Mattermost's OAuth flow checks for 
SSL on its own listener — not on the upstream proxy.

**Additional complication:**
The docker-compose.yml became corrupted after multiple nano edits, 
causing YAML parse errors:
```
yaml.scanner.ScannerError: mapping values are not allowed here
```

**Fix for corrupted YAML:**
```bash
sudo docker-compose down
nano ~/mattermost/docker-compose.yml
# Delete all content and paste clean version
sudo docker-compose up -d
```

---

## Attempt 4 — Correct Redirect URI Path

**What we tried:**
Discovered that the correct redirect URI path for Entra ID SSO in 
Mattermost is `/signup/office365/complete` — not `/signup/openid/complete`.

Per official Mattermost documentation:
> "Define the Redirect URI as Web client, then input the URL followed 
> by /signup/office365/complete"

Updated Entra redirect URI to:
```
https://tinyco-vm.tail7ee901.ts.net/signup/office365/complete
```

**Error:**
```
Office365 SSO through OAuth 2.0 not available on this server.
```

**Why it failed:**
Same root cause — Mattermost still detecting HTTP internally despite 
Nginx handling HTTPS externally.

---

## Attempt 5 — Direct Config.json Modification

**What we tried:**
Discovered that Mattermost stores two separate SSO configs:
- `Office365Settings` — the Entra ID specific OAuth config
- `OpenIdSettings` — the generic OpenID Connect config

The System Console was saving to `Office365Settings` (with Enable: true) 
but the OpenID button was checking `OpenIdSettings` (with Enable: false).

**Step 1 — Copy config from container:**
```bash
sudo docker cp mattermost_mattermost_1:/mattermost/config/config.json /tmp/mm-config.json
```

**Step 2 — Verify the issue:**
```bash
sudo grep -A 15 "Office365Settings" /tmp/mm-config.json
# Shows Enable: true with all credentials ✅

sudo grep -A 5 "OpenIdSettings" /tmp/mm-config.json  
# Shows Enable: false with empty credentials ❌
```

**Step 3 — Edit config to enable OpenIdSettings:**
```bash
sudo nano /tmp/mm-config.json
# Find OpenIdSettings, change Enable: false to Enable: true
```

**Step 4 — Copy back to container:**
```bash
sudo docker cp /tmp/mm-config.json mattermost_mattermost_1:/mattermost/config/config.json
sudo docker-compose restart mattermost
```

**Error:**
```
Error: failed to load configuration: open /mattermost/config/config.json: 
permission denied
```

**Why it failed:**
`docker cp` copies files as root. Mattermost runs as user `2000` and 
cannot read a root-owned file.

**Attempted fix — correct permissions via overlay:**
```bash
sudo find /var/lib/docker -name "config.json" -path "*/mattermost/config/*"
sudo chown 2000:2000 [path]/config.json
sudo chmod 600 [path]/config.json
```

This also failed because Docker's overlay filesystem uses multiple layers 
and the file we were modifying wasn't the active layer.

**Mattermost also overwrites config on startup** — any manual file changes 
were reset because Mattermost re-writes its canonical config on every start.

---

## Attempt 6 — Environment Variables via .env File

**What we tried:**
Used Docker environment variables to override config settings — 
environment variables take precedence over config.json in Mattermost.

**Step 1 — Create .env file:**
```bash
nano ~/mattermost/.env
```
```
MM_OPENIDSETTINGS_ENABLE=true
MM_OPENIDSETTINGS_ID=9959407c-a540-4136-b379-d47f28897a5a
MM_OPENIDSETTINGS_SECRET=488a1d29-4ac5-4365-a123-3bd709f28b59
MM_OPENIDSETTINGS_DISCOVERYENDPOINT=https://login.microsoftonline.com/42a9915e-aa4a-4426-9a86-a04a0dac6222/v2.0/.well-known/openid-configuration
MM_OPENIDSETTINGS_BUTTONTEXT=Sign in with Entra ID
```

**Step 2 — Update docker-compose.yml to load .env:**
```yaml
mattermost:
  env_file:
    - .env
```

**Step 3 — Restart:**
```bash
sudo docker-compose down
sudo docker-compose up -d
```

**Result:**
Environment variables loaded successfully — System Console shows 
"This setting has been set through an environment variable":
- Discovery Endpoint ✅
- Client ID ✅
- Client Secret ✅

**Error when clicking SSO button:**
```
OpenID SSO through OAuth 2.0 not available on this server.
```

Note: Error changed from "Office365" to "OpenID" — confirming 
`OpenIdSettings` is now enabled. But same root SSL detection issue.

---

## Root Cause Analysis

After extensive debugging, the confirmed root cause is:

**Mattermost requires SSL to terminate directly on its own process.**

When Nginx handles SSL and proxies to Mattermost on plain HTTP:
1. Mattermost receives the request on HTTP (port 8065)
2. Mattermost checks if it's serving SSL
3. It detects HTTP — not SSL
4. It refuses to initiate the OAuth flow

Even with `X-Forwarded-Proto: https` headers from Nginx, Mattermost 
does not trust proxy headers for this security check by default.

---

## Production Resolution

In a production environment, this would be resolved by one of these 
approaches in order of preference:

**Option 1 — Real domain + Let's Encrypt (Recommended)**
```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate (requires real domain pointed to this IP)
sudo certbot --nginx -d chat.yourdomain.com

# Update Mattermost Site URL
MM_SERVICESETTINGS_SITEURL: https://chat.yourdomain.com
```
Cost: ~$15/year for domain. SSL certificate is free.

**Option 2 — Mattermost direct TLS**
Configure Mattermost to handle SSL directly without Nginx:
```yaml
MM_SERVICESETTINGS_CONNECTIONSSECURITY: TLS
MM_SERVICESETTINGS_TLSCERTFILE: /path/to/cert.crt
MM_SERVICESETTINGS_TLSKEYFILE: /path/to/cert.key
```

**Option 3 — Tailscale HTTPS certificates (Enterprise plan required)**
```bash
sudo tailscale cert tinyco-vm.tail7ee901.ts.net
```
Provides valid SSL cert for Tailscale hostname automatically.
Requires Tailscale Enterprise plan.

---

## Current State

| Component | Status |
|---|---|
| Mattermost running | ✅ |
| Accessible via public IP | ✅ `http://20.63.73.34:8065` |
| Accessible via Tailscale | ✅ `https://tinyco-vm.tail7ee901.ts.net` |
| Entra SSO configured | ✅ Settings correct |
| Entra SSO working | ❌ OAuth blocked by SSL detection |
| Users can log in | ✅ Via email/password |
| Users can chat | ✅ Core functionality working |

---

## For DDG Submission

Mattermost is functional and connectable. The provided test credentials 
allow direct login. SSO configuration is complete on both the Entra 
and Mattermost sides — the remaining issue is Mattermost's SSL 
detection mechanism when running behind a reverse proxy.

**Test credentials for DDG reviewer:**
- URL: `http://20.63.73.34:8065`
- Username/Email: `[delivered via submission notes]`
- Password: `[delivered via submission notes]`