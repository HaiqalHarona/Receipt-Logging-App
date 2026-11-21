# Receipt Logger — Alpha Staging, Tailscale Tunneling & In-App OTA Update Guide

This document provides a comprehensive operational guide for the **Receipt Logger (SancFund)** Alpha Staging distribution system. It details the automated CI/CD pipeline, the Tailscale mesh VPN tunneling architecture, the Portainer Nginx distribution server, and the real-time in-app Over-The-Air (OTA) update notification workflow.

---

## 1. High-Level Architecture & Network Topology

The Alpha Staging system allows developers to push code to the `alpha` branch and have a production-signed Android APK compiled, stamped with a unique monotonic build number, securely tunneled over a zero-trust mesh VPN into a private homelab server, and immediately broadcast to mobile test devices via in-app update prompts.

```
+--------------------------------------------------------------------------------------------------------------------+
|                                      ALPHA STAGING SYSTEM TOPOLOGY                                                 |
|                                                                                                                    |
|   +--------------------------+         +-------------------------------+         +-----------------------------+   |
|   |   Developer Workstation  |         |   GitHub Actions CI/CD Runner |         |  Private Homelab Server     |   |
|   |                          |         |   (Ubuntu-Latest)             |         |  (Portainer / Docker)       |   |
|   |   git push origin alpha  | ------> |                               |         |                             |   |
|   +--------------------------+         |   1. Analyze & Test           |         |  Tailscale IP:              |   |
|                                        |   2. Build SancFund.apk       |         |  100.98.101.54              |   |
|                                        |   3. Gen staging_manifest.json|         |                             |   |
|                                        +---------------+---------------+         |  +-----------------------+  |   |
|                                                        |                         |  | Portainer Staging App |  |   |
|                                                        | Tailscale Mesh Tunnel   |  | Nginx Alpine on :9090 |  |   |
|                                                        | (Encrypted WireGuard)   |  | /opt/apk-server/apks/ |  |   |
|                                                        v                         |  +-----------+-----------+  |   |
|                                        +-------------------------------+         +--------------|--------------+   |
|                                        |  SCP Deployment over Mesh VPN | ------------------------+                 |
|                                        |  & Trigger Portainer Webhook  |                                           |
|                                        +-------------------------------+                                           |
|                                                                                                                    |
|                                                                                         |                          |
|                                                                                         | HTTP GET /manifest       |
|                                                                                         v                          |
|                                                                          +-----------------------------+           |
|                                                                          |   Mobile Test Device        |           |
|                                                                          |   (Alpha SancFund App)      |           |
|                                                                          |                             |           |
|                                                                          |   1. Polls Manifest         |           |
|                                                                          |   2. Compares Build Number  |           |
|                                                                          |   3. Pops StagingDialog     |           |
|                                                                          |   4. Downloads SancFund.apk |           |
|                                                                          +-----------------------------+           |
+--------------------------------------------------------------------------------------------------------------------+
```

---

## 2. End-to-End Automated Workflow

```mermaid
sequenceDiagram
  autonumber
  actor Dev as Developer
  participant Git as GitHub (alpha branch)
  participant CI as GitHub Actions Runner
  participant TS as Tailscale Mesh VPN
  participant Server as Homelab APK Server (100.98.101.54:9090)
  participant Webhook as Portainer Webhook
  actor Tester as Mobile Test User
  participant App as SancFund Mobile App (OtaUpdateService)

  Dev->>Git: git push origin alpha
  Git->>CI: Trigger Workflow (.github/workflows/ci.yml)
  
  rect rgb(240, 248, 255)
    Note over CI: Phase 1 — Verification Gate
    CI->>CI: flutter pub get
    CI->>CI: dart format & flutter analyze (0 warnings)
    CI->>CI: flutter test --coverage (115+ tests pass)
  end

  rect rgb(255, 250, 240)
    Note over CI: Phase 2 — Compilation & Stamping
    CI->>CI: Extract GitHub Run Number ($BUILD_NUM)
    CI->>CI: Build APK with --build-number=$BUILD_NUM & --dart-define=APP_BUILD_NUMBER
    CI->>CI: Copy app-release.apk -> SancFund.apk
    CI->>CI: Generate staging_manifest.json with build metadata & timestamp
  end

  rect rgb(240, 255, 240)
    Note over CI,Server: Phase 3 — Tailscale Secure Delivery
    CI->>TS: Authenticate via TAILSCALE_AUTHKEY
    CI->>Server: SCP SancFund.apk, staging_manifest.json, index.html to /opt/apk-server/apks/
    CI->>Webhook: Trigger Portainer stack redeploy (HTTP POST)
  end

  rect rgb(255, 240, 245)
    Note over App,Tester: Phase 4 — In-App OTA Update & Ping
    Tester->>App: Launch App or Resume from Background
    App->>Server: GET http://100.98.101.54:9090/staging_manifest.json
    Server-->>App: StagingManifest JSON (buildNumber: 42)
    App->>App: Compare (remote.buildNumber > local.buildNumber)
    App->>Tester: Display StagingUpdateDialog with release notes & Update CTA
    Tester->>App: Tap "Update Now"
    App->>Server: Download and Install SancFund.apk
  end
```

---

## 3. Automated CI/CD Pipeline (`.github/workflows/ci.yml`)

The CI/CD pipeline consists of three sequential jobs executed on push to `alpha`:

### Job 1: `analyze-and-test`
1. Checks out repository and configures **Java 17 (Temurin)** and **Flutter Stable SDK**.
2. Creates a mock `.env` file to ensure hermetic compilation without leaking credentials.
3. Enforces strict code quality gates:
   - `dart format --output=none --set-exit-if-changed lib test`
   - `flutter analyze`
   - `flutter test --coverage`
4. Uploads code coverage reports as workflow artifacts.

### Job 2: `build-android`
1. Extracts the unique monotonic **GitHub Run Number** as the build number (`BUILD_NUM=${{ github.run_number }}`).
2. Compiles the APK injecting build configuration via `--dart-define`:
   ```bash
   BUILD_NUM=${{ github.run_number }}
   VERSION_NAME="1.0.1"
   VERSION_DISPLAY="1.0.1.0.${BUILD_NUM}"
   
   flutter build apk --release --no-tree-shake-icons \
     --build-name="${VERSION_NAME}" \
     --build-number="${BUILD_NUM}" \
     --dart-define=APP_ENV=alpha \
     --dart-define=APP_VERSION="${VERSION_NAME}" \
     --dart-define=APP_BUILD_NUMBER="${BUILD_NUM}" \
     --dart-define=APP_VERSION_DISPLAY="${VERSION_DISPLAY}" \
     --dart-define=STAGING_MANIFEST_URL="http://100.98.101.54:9090/staging_manifest.json" \
     --dart-define=API_BASE_URL="http://100.98.101.54:8085/api/v1" \
     --dart-define=FASTAPI_BASE_URL="http://100.98.101.54:8085"
   ```
3. Renames the output to a clean standard filename:
   ```bash
   cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/SancFund.apk
   ```
4. Generates `build/staging/staging_manifest.json`:
   ```json
   {
     "stage": "Alpha",
     "channel": "staging",
     "version": "1.0.1",
     "buildNumber": 42,
     "versionDisplay": "1.0.1.0.42",
     "downloadUrl": "http://100.98.101.54:9090/SancFund.apk",
     "releaseNotes": "Automated Alpha build from commit abc1234 on alpha",
     "publishedAt": "2026-08-27T16:30:00Z"
   }
   ```

### Job 3: `deploy-to-tailscale-server`
1. Connects the ephemeral GitHub Actions runner to the private Tailscale mesh network using `tailscale/github-action@v3`.
2. Securely transfers the build artifacts over SSH using the deployment key:
   - `SancFund.apk` -> `/opt/apk-server/apks/SancFund.apk`
   - `staging_manifest.json` -> `/opt/apk-server/apks/staging_manifest.json`
   - `deploy/apk-server/index.html` -> `/opt/apk-server/apks/index.html`
3. Issues a webhook POST to Portainer to ensure live file refresh.

---

## 4. Portainer APK Distribution Server Architecture

The distribution server runs inside Docker managed via Portainer on the homelab host (`100.98.101.54`).

### Docker Compose Stack (`deploy/apk-server/docker-compose.yml`)
```yaml
version: '3.8'

services:
  apk-server:
    image: nginx:alpine
    container_name: apk-distribution-server
    restart: unless-stopped
    ports:
      - "9090:80"
    volumes:
      - /opt/apk-server/apks:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

### Nginx MIME Types & Cache Headers (`deploy/apk-server/nginx.conf`)
```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;

    types {
        text/html html;
        text/css css;
        image/svg+xml svg;
        application/vnd.android.package-archive apk;
        application/json json;
    }

    # Manifest must never be cached by mobile clients
    location = /staging_manifest.json {
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
        expires off;
    }

    location / {
        autoindex off;
        try_files $uri $uri/ /index.html;
    }
}
```

### Web Portal (`deploy/apk-server/index.html`)
The distribution endpoint includes a standalone responsive web portal:
- Accessible at `http://100.98.101.54:9090/`.
- Dynamically queries `staging_manifest.json` upon load.
- Displays current Version Badge (`v1.0.1.0.42`), Stage (`Alpha Staging`), and Build Timestamp.
- Provides a single-click download button that downloads `SancFund.apk`.
- Displays latest commit release notes.
- Locked to viewport (`height: 100vh; overflow: hidden`) with zero unnecessary scrollbars.

---

## 5. In-App Over-The-Air (OTA) Update System

The Flutter mobile application includes active update detection and user notification mechanisms:

### 1. `OtaUpdateService` (`lib/services/ota_update_service.dart`)
- **Lifecycle Hook**: Listens to app startup and `AppLifecycleState.resumed` events.
- **Manifest Polling**: Fetches `http://100.98.101.54:9090/staging_manifest.json` with a 5-second HTTP timeout.
- **Version Comparison**:
  ```dart
  bool isUpdateAvailable = remoteManifest.buildNumber > ApiConfig.appBuildNumber;
  ```
- **Cooldown Guard**: Prevents repeatedly bugging users by respecting a 24-hour snooze if dismissed.

### 2. `StagingUpdateDialog` (`lib/ui/core/widgets/staging_update_dialog.dart`)
When an update is detected, a modal dialog renders on screen:
- **Title**: `🚀 New Alpha Update Available`
- **Version Badge**: Displays `1.0.1.0.<newBuild>` vs current `1.0.1.0.<currentBuild>`.
- **Release Notes**: Renders changelog and commit hash.
- **Primary CTA ("Update Now")**: Launches the download URL (`http://100.98.101.54:9090/SancFund.apk`) via Android package installer or default browser.
- **Secondary CTA ("Later")**: Snoozes update alerts for 24 hours.

### 3. `AlphaBreadcrumbBadge` (`lib/ui/core/widgets/alpha_breadcrumb_badge.dart`)
- Positioned in the bottom navigation bar and settings header.
- Displays the formatted build tag (e.g. `ALPHA v1.0.1.0.42`).
- **Interactive Tap Action**: Tapping the badge forces an immediate manual check against the staging server and triggers the update dialog if an update exists.

---

## 6. Android OS Installation Permissions

To allow in-app APK installation on Android 8.0+ (Oreo through Android 15), the app manifest defines:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
    <uses-permission android:name="android.permission.CAMERA" />
</manifest>
```

---

## 7. Versioning Conventions & Build Stamping

The version format is strictly standardized across the entire ecosystem:

$$\text{Version Display} = \underbrace{\text{MAJOR}}_{\text{1}}.\underbrace{\text{MINOR}}_{\text{0}}.\underbrace{\text{PATCH}}_{\text{1}}.\underbrace{\text{STAGE}}_{\text{0 = Alpha}}.\underbrace{\text{BUILD NUMBER}}_{\text{GitHub Run Number}}$$

| Component | Example | Description |
|---|---|---|
| **`APP_VERSION`** | `1.0.1` | Base semantic version name from release milestones. |
| **`APP_BUILD_NUMBER`** | `42` | Monotonically increasing integer from GitHub Actions run number. |
| **`APP_VERSION_DISPLAY`**| `1.0.1.0.42` | Full user-facing breadcrumb badge string. |
| **`APP_ENV`** | `alpha` | Active environment mode (`development`, `alpha`, `staging`, `production`). |

---

## 8. GitHub Secrets Configuration Matrix

Ensure the following repository secrets are configured in GitHub (`Settings -> Secrets and variables -> Actions`):

| Secret Name | Example Value | Description |
|---|---|---|
| `TAILSCALE_AUTHKEY` | `tskey-auth-k123456789...` | Ephemeral reusable Tailscale auth key with tag `tag:ci`. |
| `SERVER_HOST` | `100.98.101.54` | Tailscale IP of the homelab Portainer server. |
| `SERVER_USER` | `deployer` | SSH username on the staging server. |
| `SERVER_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | Ed25519 or RSA private key authorized on staging server. |
| `SERVER_DEST_PATH` | `/opt/apk-server/apks` | Absolute path where Nginx mounts APKs and manifests. |
| `PORTAINER_WEBHOOK_URL`| `https://portainer.local:9443/api/stacks/webhooks/...` | Portainer Stack redeploy webhook URL. |
| `FASTAPI_BASE_URL` | `http://100.98.101.54:8085` | Backend API URL reachable over Tailscale network. |
| `API_BASE_URL` | `http://100.98.101.54:8085/api/v1` | Base API endpoint prefix. |

---

## 9. Verification & Troubleshooting

### Issue: Test user receives no update alert
1. **Verify Tailscale Connection**: Ensure the test device is authenticated to the Tailscale mesh or on the local homelab LAN.
2. **Check Manifest Reachability**: On the test device browser, navigate to `http://100.98.101.54:9090/staging_manifest.json`. It should return clean JSON.
3. **Inspect App Build Number**: Check `AlphaBreadcrumbBadge`. If local build number equals remote manifest `buildNumber`, the app is already up to date.
4. **Force Manual Check**: Tap the `AlphaBreadcrumbBadge` on the Settings screen to trigger an immediate check and bypass snooze cooldowns.
