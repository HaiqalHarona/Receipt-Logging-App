# Receipt Logger

A privacy-first, offline-first mobile and web application built with Flutter for scanning receipts, extracting structured data using Google Gemini 3.6 Flash Vision AI, and tracking spending trends with a Neumorphic design system.

---

## Documentation Index

Comprehensive documentation is organized under the `docs/` directory:

### AI Context & Architecture
Architectural blueprints, endpoint matrices, and project structural specifications intended for AI agents and core architecture references:

- **[Project Scope & Architecture](file:///docs/ai_context/PROJECT_SCOPE.md)**: End-to-end processing pipeline, 20-endpoint backend matrix, hardware device token verification, rate limit handling, and active route mapping.
- **[Project Structure](file:///docs/ai_context/PROJECT_STRUCTURE.md)**: Feature-first directory breakdown, layered service architecture, Riverpod state management, Isar local persistence, and GoRouter declarative navigation.

### Developer & Team Guides
Guides for backend API integration, data flow pipelines, git branching strategy, CI/CD automation, and agent swarm protocols:

- **[Backend API Specification](file:///docs/user_guides/API.md)**: FastAPI backend documentation, header authentication contract (`X-Device-ID`, `X-Device-Token`), endpoints catalog, parsing flowcharts, and local server startup.
- **[Data Flow & Workflow Guide](file:///docs/user_guides/DATA_FLOW_AND_WORKFLOW.md)**: Complete lifecycle of data across Flutter UI, Isar local database, FastAPI backend, Redis job queues, Gemini Vision AI, and Supabase cloud sync.
- **[Git Branching & CI/CD Guide](file:///docs/user_guides/BRANCHING_AND_CICD.md)**: Dual-trunk / Light GitFlow workflow, branch protection rules, and GitHub Actions automated pipeline breakdown (`analyze-and-test`, `build-android`, `build-web`).
- **[Agent Swarm Specifications](file:///docs/user_guides/AGENTS.md)**: Subagent roles (`@ui_builder`, `@test_writer`, `@janitor`), handoff protocols, and coding constraints.

---

## Getting Started

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
```

---

## Tech Stack Summary

- **Framework**: Flutter 3.x / Dart 3.x+ (pinned via FVM 3.44.8)
- **State Management**: Riverpod 2.x (`flutter_riverpod`)
- **Local Database**: Isar 3.x (`isar`, `isar_flutter_libs`)
- **Design System**: Neumorphic UI (`flutter_neumorphic_plus`) with dynamic theme controller
- **Backend & Vision AI**: FastAPI, Supabase, Google Gemini 3.6 Flash
- **Navigation**: GoRouter 14.x with persistent shell tabs and Neumorphic page transitions
- **CI/CD**: GitHub Actions (`.github/workflows/ci.yml`)
