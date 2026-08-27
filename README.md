# Receipt Logger (SancFund)

A privacy-first, offline-first mobile application built with Flutter for scanning receipts, extracting structured transaction data using Google Gemini 3.6 Flash Vision AI, and tracking spending trends with an elegant Neumorphic design system.

---

## 📚 Documentation Index

Comprehensive documentation is organized under the [`docs/`](docs/) directory:

### 🧠 AI Context & System Architecture
Architectural blueprints, directory trees, endpoint matrices, and structural specifications intended for AI agents and core architecture references:

- **[Project Scope & Architecture Blueprint](docs/ai_context/PROJECT_SCOPE.md)**: End-to-end processing pipeline, 23-endpoint backend matrix, rate limit handling, local database export, and active route mapping.
- **[Project Structure & Directory Tree](docs/ai_context/PROJECT_STRUCTURE.md)**: Feature-first directory breakdown, layered Clean Architecture, Riverpod 2.x state management, Isar 3.x local database, and GoRouter declarative navigation.

### 🛠️ Developer & Team User Guides
Guides for backend API integration, data flow pipelines, git branching strategy, CI/CD automation, alpha staging delivery, and agent swarm protocols:

- **[Alpha Staging, Tailscale Tunneling & OTA Updates](docs/user_guides/ALPHA_STAGING.md)**: Continuous Alpha staging delivery, Tailscale mesh VPN tunneling, Portainer Nginx APK distribution server (`:9090`), and real-time in-app update notifications.
- **[Backend API Specification](docs/user_guides/API.md)**: Complete FastAPI v1 backend documentation, header authentication contract (`X-Request-Type`, `X-Device-ID`, `X-Device-Token`), SSE streaming, and endpoint schemas.
- **[Data Flow & Workflow Guide](docs/user_guides/DATA_FLOW_AND_WORKFLOW.md)**: Full lifecycle of data across Flutter UI, local Isar DB, FastAPI backend, Redis job queues, Gemini Vision AI, and Supabase cloud sync.
- **[Git Branching & CI/CD Guide](docs/user_guides/BRANCHING_AND_CICD.md)**: Dual-trunk / Light GitFlow workflow, branch protection rules, and GitHub Actions automated pipeline breakdown (`analyze-and-test`, `build-android`, `deploy-to-tailscale-server`).
- **[Agent Swarm Specifications](docs/user_guides/AGENTS.md)**: Subagent roles (`@ui_builder`, `@test_writer`, `@janitor`), handoff protocols, and coding constraints.

### ⚖️ Legal & Compliance Documents
In-app legal documents rendered dynamically via the Markdown viewer:

- **[Terms of Service](docs/legal_docs/TERMS_OF_SERVICE.md)**
- **[Privacy Policy](docs/legal_docs/PRIVACY_POLICY.md)**
- **[Cookie Policy](docs/legal_docs/COOKIE_POLICY.md)**
- **[Accessibility Statement](docs/legal_docs/ACCESSIBILITY_STATEMENT.md)**

---

## 🚀 Getting Started

### Prerequisites & FVM Setup

This repository uses **FVM (Flutter Version Management)** to enforce a consistent Flutter SDK version across team members and CI runners.

#### 1. Install FVM Globally
```bash
dart pub global activate fvm
```
Ensure your pub cache bin directory (`%LOCALAPPDATA%\Pub\Cache\bin` on Windows or `~/.pub-cache/bin` on macOS/Linux) is added to your system `PATH`.

#### 2. Install Project Flutter SDK
After cloning this repository, navigate to the project directory and run:
```bash
fvm install
```
This installs the pinned Flutter SDK version (`3.44.8`) specified in `.fvmrc`.

#### 3. IDE Configuration
The project includes `.vscode/settings.json` configured to use `.fvm/flutter_sdk`. When prompted by VS Code, select the FVM SDK.

#### 4. Running the Application
Prefix all Flutter commands with `fvm`:
```bash
# Install dependencies
fvm flutter pub get

# Run on connected device / emulator
fvm flutter run

# Run test suite with coverage
fvm flutter test --coverage

# Run static analysis
fvm flutter analyze

# Format code
dart format lib test
```

---

## 🏗️ Tech Stack Summary

| Layer | Technology | Details |
|---|---|---|
| **Framework** | Flutter 3.x / Dart 3.x+ | Pinned via FVM (`3.44.8`) |
| **State Management** | Riverpod 2.x | `flutter_riverpod`, `AsyncNotifier`, `NotifierProvider` |
| **Local Database** | Isar 3.x | Offline-first encrypted binary storage (`isar`, `isar_flutter_libs`) |
| **Data Export** | `DataExportService` | Zero-cloud local database backup to JSON and CSV |
| **Design System** | Neumorphic Design | `flutter_neumorphic_plus`, custom tokens, dynamic theme presets, font scaling |
| **Backend & Vision AI** | FastAPI + Gemini 3.6 Flash | Multimodal structured OCR, SSE batch streams, Redis async queues |
| **Cloud Sync & Auth** | Supabase | PostgreSQL DB, pgvector embeddings, JWT authentication |
| **Navigation** | GoRouter 14.x | URL-style declarative routing with Neumorphic transitions |
| **Staging & OTA** | Tailscale + Portainer | Private mesh VPN deployment, Nginx APK portal, in-app update polling |
| **CI/CD** | GitHub Actions | Format checks, static analysis, unit/widget tests (115+), automated APK release |
