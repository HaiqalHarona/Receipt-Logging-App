---
name: homelab-portainer-apk-distribution
description: Deploy a lightweight, self-contained Nginx auto-index APK file server on Portainer for over-the-air (OTA) mobile app testing over LAN and Tailscale.
metadata:
  version: "1.0.0"
---

# Homelab Portainer APK Distribution

## Core Pattern: Self-Contained Docker Compose

Avoid relative file bind mounts (e.g. `./nginx.conf`) and image build/pull lookup errors in Portainer Git Stacks by using the official public `nginx:alpine` image and generating the Nginx auto-index configuration and Android MIME types dynamically at container startup:

```yaml
services:
  apk-server:
    image: nginx:1.27-alpine
    container_name: apk-server
    restart: unless-stopped
    ports:
      - "9090:80"
    volumes:
      - /opt/apk-server/apks:/usr/share/nginx/html/apks:ro
    command:
      - /bin/sh
      - -c
      - |
        printf 'server {\n    listen 80;\n    server_name _;\n    root /usr/share/nginx/html/apks;\n    autoindex on;\n    autoindex_exact_size off;\n    autoindex_localtime on;\n    location / {\n        types { }\n        default_type application/vnd.android.package-archive;\n    }\n    location /ping {\n        return 200 "ok";\n        add_header Content-Type text/plain;\n    }\n}\n' > /etc/nginx/conf.d/default.conf
        exec nginx -g 'daemon off;'
```

---

## Server Host Setup Commands

Run once on the homelab host:
```bash
# 1. Create directory structure
sudo mkdir -p /opt/apk-server/apks

# 2. Grant permissions
sudo chmod -R 755 /opt/apk-server

# 3. Set ownership to regular user so SCP uploads work without sudo
sudo chown -R $USER:$USER /opt/apk-server/apks
```

---

## Portainer Stack Deployment (Repository Mode)

1. Open Portainer → **Stacks** → **Add stack** → Select **Repository**.
2. **Name**: `apk-server`
3. **Repository URL**: `https://github.com/<owner>/<repo>.git`
4. **Repository reference**: `refs/heads/develop` (or `main`)
5. **Compose path**: `deploy/apk-server/docker-compose.yml`
6. Click **Deploy the stack**.

---

## Releasing & Uploading New Builds

```bash
# 1. Compile release APK
fvm flutter build apk --release --no-tree-shake-icons

# 2. Upload to server via SCP (zero container downtime)
scp build/app/outputs/flutter-apk/app-release.apk user@<server-ip>:/opt/apk-server/apks/receipt-logger.apk
```

---

## Tester Access

- **Local Wi-Fi**: `http://<homelab-lan-ip>:9090`
- **Tailscale (Remote)**: `http://<homelab-tailscale-ip>:9090`
- Testers visit the URL on Android, tap the `.apk` file name, and install directly.
