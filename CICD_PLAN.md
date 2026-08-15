# Implementation Plan — Flutter CI/CD Pipeline Configuration

> **Status: ✅ IMPLEMENTED** — Workflow configured at [`.github/workflows/ci.yml`](file:///.github/workflows/ci.yml). Branching model and developer guide documented at [`BRANCHING_AND_CICD.md`](file:///BRANCHING_AND_CICD.md).

This document outlines the architecture and implementation strategy established for the **GitHub Actions CI/CD Pipeline** and **Dual-Trunk Git Branching Model** for the Flutter Receipt Logging application.

---

## Goal Description
Automate code verification, static analysis, unit & widget testing with code coverage reporting, and multi-platform build generation (Android APK and Web bundles) across `master`, `main`, and `develop` branches.

---

## User Review Required

> [!IMPORTANT]
> **Flutter & Java Version Alignment**
> - **Flutter Version**: Using Sub-action `subosito/flutter-action@v2` configured with Flutter `3.24.x` (or `stable` channel matching Dart SDK `^3.5.0` specified in [`pubspec.yaml`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/pubspec.yaml#L8)).
> - **Java Version**: Using Java 17 (OpenJDK) for modern Android Gradle builds.

> [!NOTE]
> **Environment & Secret Injection**
> The app depends on `.env` (referenced in [`pubspec.yaml`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/pubspec.yaml#L77)). In CI, a dummy `.env` or secret-populated `.env` file will be generated dynamically during the workflow run before testing or building.

---

## Open Questions

> [!NOTE]
> No unresolved blockers. The pipeline strategy defaults to GitHub Actions with comprehensive lint, test, Android APK build, and Web build stages.

---

## Proposed Changes

### CI/CD Workflow Component

#### [NEW] [`.github/workflows/ci.yml`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/.github/workflows/ci.yml)

Create a GitHub Actions workflow with 3 parallel/sequential jobs:
1. **`analyze-and-test`**:
   - Checkout code with `actions/checkout@v4`.
   - Set up Java 17 (`actions/setup-java@v4`).
   - Set up Flutter SDK with `subosito/flutter-action@v2` (channel `stable`, caching enabled).
   - Generate temporary dummy `.env` file (`SUPABASE_URL=...`, `SUPABASE_ANON_KEY=...`).
   - Run `flutter pub get`.
   - Run formatting check: `dart format --output=none --set-exit-if-changed .`
   - Run static analysis: `flutter analyze`
   - Run test suite: `flutter test --coverage`
   - Upload test coverage artifact (`coverage/lcov.info`).

2. **`build-android`** (depends on `analyze-and-test`):
   - Set up Java 17 & Flutter SDK.
   - Run `flutter pub get`.
   - Generate `.env`.
   - Run `flutter build apk --release`.
   - Upload APK artifact (`build/app/outputs/flutter-apk/app-release.apk`) to GitHub Actions Run Artifacts.

3. **`build-web`** (depends on `analyze-and-test`):
   - Set up Flutter SDK.
   - Run `flutter pub get`.
   - Generate `.env`.
   - Run `flutter build web --release`.
   - Upload Web bundle artifact (`build/web`) to GitHub Actions Run Artifacts.

```yaml
name: Flutter CI/CD Pipeline

on:
  push:
    branches: [ main, master, dev ]
  pull_request:
    branches: [ main, master, dev ]
  workflow_dispatch:

jobs:
  analyze-and-test:
    name: 🧪 Analyze & Test
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: ☕ Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: 🐦 Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
          cache-key: "flutter-:os:-:channel:-:version:-:arch:-:hash:"
          cache-path: "${{ runner.tool_cache }}/flutter"

      - name: 🔑 Create Dummy .env for CI
        run: |
          echo "SUPABASE_URL=https://dummy.supabase.co" > .env
          echo "SUPABASE_ANON_KEY=dummy_key" >> .env
          echo "FASTAPI_BASE_URL=https://dummy.api.com" >> .env

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 📐 Check formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: 🔍 Run static analysis
        run: flutter analyze

      - name: 🧪 Run tests with coverage
        run: flutter test --coverage

      - name: 📊 Upload Coverage Report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/lcov.info
          if-no-files-found: ignore

  build-android:
    name: 🤖 Build Android APK
    needs: analyze-and-test
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: ☕ Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: 🐦 Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: 🔑 Create Dummy .env for CI
        run: |
          echo "SUPABASE_URL=https://dummy.supabase.co" > .env
          echo "SUPABASE_ANON_KEY=dummy_key" >> .env
          echo "FASTAPI_BASE_URL=https://dummy.api.com" >> .env

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 🏗️ Build APK
        run: flutter build apk --release

      - name: 📤 Upload Android APK
        uses: actions/upload-artifact@v4
        with:
          name: android-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-web:
    name: 🌐 Build Web App
    needs: analyze-and-test
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: 🐦 Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: 🔑 Create Dummy .env for CI
        run: |
          echo "SUPABASE_URL=https://dummy.supabase.co" > .env
          echo "SUPABASE_ANON_KEY=dummy_key" >> .env
          echo "FASTAPI_BASE_URL=https://dummy.api.com" >> .env

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 🏗️ Build Web Release
        run: flutter build web --release

      - name: 📤 Upload Web Build Artifact
        uses: actions/upload-artifact@v4
        with:
          name: web-release-bundle
          path: build/web
```

---

### Documentation Component

#### [MODIFY] [`README.md`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/README.md)
Update [`README.md`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/README.md) to add a **CI/CD Pipeline** section detailing pipeline status badges, local verification commands, and environment setup for CI runs.

---

## Verification Plan

### Automated Tests
Run the following local commands in order to mirror every stage of the CI pipeline prior to pushing:
```bash
# 1. Format check
dart format --output=none --set-exit-if-changed .

# 2. Static analysis
flutter analyze

# 3. Test execution with coverage
flutter test --coverage

# 4. Web Build verification
flutter build web --release
```

### Manual Verification
1. Inspect generated `.github/workflows/ci.yml` YAML syntax.
2. Verify local execution of `flutter analyze` and `flutter test` completes with 0 errors.
3. Review uploaded CI artifacts structure upon workflow execution on GitHub.
