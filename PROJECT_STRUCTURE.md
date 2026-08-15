# Receipt Logger — Project Structure & Architecture

## Overview
The **Receipt Logger** codebase follows Flutter architecture best practices, leveraging a **Feature-First / Layered Architecture** with **Riverpod 2.x** for state management, **Isar 3.x** for offline-first local storage, **flutter_neumorphic_plus** for the design system, **http** for Vision AI backend integration, and **GoRouter** for declarative navigation.

For the full 9-screen scope breakdown and 20-endpoint backend matrix, see [PROJECT_SCOPE.md](file:///C:/mobile-development/receipt_logging_app/PROJECT_SCOPE.md).

---

## Complete Directory Breakdown

```
receipt_logging_app/
├── .agents/                    # Custom agentic skills & engineering standards
│   └── skills/                 # Specialized Flutter/Dart skills & guidelines
├── android/                    # Android native platform code & permissions config
├── ios/                        # iOS native platform runner & Info.plist permissions
├── lib/                        # Core Application Source Code
│   ├── data/                   # Data access layer
│   │   ├── models/             # Isar collection data schemas (receipt.dart, receipt_item.dart)
│   │   └── repositories/       # Data access repositories (receipt_repository.dart)
│   ├── services/               # External network & background services
│   │   ├── api/                # FastAPI Backend REST Client Package
│   │   │   ├── api_config.dart # Base URL, device headers & timeout configuration
│   │   │   ├── api_models.dart # DTO schemas (Receipt, LineItem, User, Device, Chat DTOs)
│   │   │   └── backend_api_client.dart # BackendApiClient & RateLimitException
│   │   ├── currency_service.dart # Currency formatting & symbol helpers
│   │   ├── isar_service.dart   # Isar database initialization & singleton management
│   │   ├── ocr_service.dart    # Vision OCR scanning orchestration
│   │   └── sync_service.dart   # Connectivity detection & offline sync queue
│   ├── ui/                     # UI Presentation layer
│   │   ├── core/               # Shared cross-cutting UI modules
│   │   │   ├── constants/      # App constants (categories, colors, default API endpoint)
│   │   │   ├── providers/      # Global Riverpod providers (Isar DB, Theme, API client)
│   │   │   ├── router/         # GoRouter configuration & route definitions
│   │   │   ├── theme/          # Neumorphic design system token values & styles
│   │   │   └── widgets/        # Reusable core components (CategoryChip, GlassCard)
│   │   └── features/           # Feature-first screen modules
│   │       ├── dashboard/      # Home dashboard & spending summaries
│   │       ├── receipt_detail/ # Itemized transaction detail & editor view
│   │       ├── scanner/        # Camera preview, Vision AI parsing & verification sheet
│   │       ├── settings/       # App settings, API URL config & data management
│   │       └── splash/         # Initial animated splash screen
│   └── main.dart               # App entry point & ProviderScope / NeumorphicTheme root
├── test/                       # Unit and widget test suite
│   ├── unit/                   # Unit tests (repository, API service, state notifiers)
│   └── widget_test.dart        # Main widget smoke test
└── pubspec.yaml                # Package dependencies & asset configuration
```

---

## Why Each Feature Has Its Own Directory (Feature-First Architecture)

Each screen/feature in `lib/ui/features/` resides in its own isolated folder (e.g., `lib/ui/features/scanner/`, `lib/ui/features/dashboard/`) for the following reasons:

1. **Encapsulation & Cohesion**:
   - All views, sub-widgets, local state controllers, and helper utilities specific to a feature remain strictly grouped within that feature's directory.
   - Prevents global shared directories (`lib/ui/core/widgets/`) from becoming bloated with single-use widgets.

2. **Scalability & Feature Growth**:
   - When expanding a feature—such as adding a custom filter sheet to `dashboard/` or an editing modal to `scanner/`—new files are placed alongside the parent feature without polluting unrelated modules.

3. **Ease of Maintenance & Code Navigation**:
   - Developers can locate and refactor everything related to a single user view in one self-contained directory.

---

## Routing Strategy & Package

### Is it using default routing or an external package?
The app uses an **external package**: [`go_router`](https://pub.dev/packages/go_router) (`v14.8.1`).

### Implementation Details:
- The route table is defined declaratively inside [`lib/ui/core/router/app_router.dart`](file:///C:/mobile-development/receipt_logging_app/lib/ui/core/router/app_router.dart) as a Riverpod `Provider<GoRouter>` (`routerProvider`).
- Integrated into the app root via `MaterialApp.router` in [`lib/main.dart`](file:///C:/mobile-development/receipt_logging_app/lib/main.dart#L30).

### Key Advantages of `go_router` Over Default Navigator:
- **Declarative & Path-Based**: Uses URL-style path strings (e.g., `/splash`, `/scanner`, `/dashboard`, `/dashboard/receipt/:id`, `/settings`).
- **Path Parameter Passing**: Supports typed parameters directly via route parameters (e.g., `state.pathParameters['id']`).
- **Riverpod Integration**: Route state reacts seamlessly to authentication, theme, or sync changes.
- **Deep Linking & Platform Support**: Ready for web browser URLs and mobile deep links out-of-the-box.
