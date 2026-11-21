# Receipt Logger — Project Structure & Architecture

## Overview
The **Receipt Logger** codebase follows Flutter architecture best practices, leveraging a **Feature-First / Layered Clean Architecture** with **Riverpod 2.x** for state management, **Isar 3.x** for offline-first local storage, **flutter_neumorphic_plus** for the design system, **http** and **dio** for Vision AI backend integration, and **GoRouter** for declarative navigation.

For the full active screen scope breakdown and 23-endpoint backend matrix, see [PROJECT_SCOPE.md](file:///docs/ai_context/PROJECT_SCOPE.md).

---

## Complete Directory Breakdown

```
receipt_logging_app/
├── .agents/                    # Custom agentic skills & engineering standards
│   └── skills/                 # Specialized Flutter/Dart skills & guidelines
├── .github/                    # CI/CD Workflows
│   └── workflows/
│       └── ci.yml              # Multi-stage CI/CD: analyze, test, APK build & Tailscale deploy
├── android/                    # Android native platform code & permissions config
│   └── app/src/main/
│       └── AndroidManifest.xml # Permissions (INTERNET, REQUEST_INSTALL_PACKAGES, CAMERA)
├── deploy/                     # Homelab & Deployment Infrastructure
│   └── apk-server/
│       ├── docker-compose.yml  # Nginx Alpine container config on port 9090
│       ├── nginx.conf          # Autoindex & MIME types configuration
│       └── index.html          # Branded single-card APK download portal with live manifest fetch
├── docs/                       # Project Documentation
│   ├── ai_context/             # AI architectural context & specifications
│   │   ├── PROJECT_SCOPE.md    # End-to-end scope, screen routes, and API matrix
│   │   └── PROJECT_STRUCTURE.md# Directory tree & architectural layer definitions
│   ├── legal_docs/             # In-app legal markdown documents
│   │   ├── ACCESSIBILITY_STATEMENT.md
│   │   ├── COOKIE_POLICY.md
│   │   ├── PRIVACY_POLICY.md
│   │   └── TERMS_OF_SERVICE.md
│   └── user_guides/            # Engineering & workflow documentation
│       ├── AGENTS.md           # Agent swarm roles, constraints, and handoff protocols
│       ├── ALPHA_STAGING.md    # Continuous alpha staging, Tailscale tunneling & OTA updates
│       ├── API.md              # Complete FastAPI backend API v1 documentation
│       ├── BRANCHING_AND_CICD.md # Git branching strategy & CI/CD pipeline guide
│       └── DATA_FLOW_AND_WORKFLOW.md # Multi-tier data lifecycle & interaction flows
├── ios/                        # iOS native platform runner & Info.plist permissions
├── lib/                        # Core Application Source Code
│   ├── cloud/                  # Cloud API & Remote Synchronization
│   │   ├── api/                # REST API clients & endpoint configurations
│   │   │   ├── api_config.dart # Environment URLs, stage detection & build metadata
│   │   │   └── backend_api_client.dart # FastAPI REST client with retry logic
│   │   ├── models/             # DTO data schemas (User, Device, Chat, Receipt DTOs)
│   │   └── services/           # Authentication, device identity & Supabase services
│   ├── data/                   # Data Access & Mapping Layer
│   │   ├── mappers/            # Isar <-> Domain <-> DTO bidirectional mappers
│   │   ├── models/             # Isar database schemas (receipt_isar, conversation_isar, etc.)
│   │   └── repositories/       # Single-source-of-truth repositories
│   ├── domain/                 # Pure Domain Layer
│   │   └── models/             # Immutable business domain models (Receipt, LineItem, Conversation)
│   ├── services/               # Core Application Services
│   │   ├── app_logger_service.dart     # Timestamped structured console logging
│   │   ├── category_service.dart       # User-defined custom categories
│   │   ├── cloud_sync_service.dart     # Background delta sync queue
│   │   ├── crypto_service.dart         # SHA-256 / HMAC constant-time hashing
│   │   ├── currency_service.dart       # Currency formatting & symbols
│   │   ├── data_export_service.dart    # Zero-network local Isar export (JSON & CSV)
│   │   ├── isar_service.dart           # Isar database lifecycle & singleton
│   │   ├── local_image_cache_service.dart # Local file storage for receipt scans
│   │   ├── ota_update_service.dart     # Alpha staging manifest check & download
│   │   └── user_preferences_service.dart # SharedPreferences settings persistence
│   ├── ui/                     # UI Presentation Layer
│   │   ├── core/               # Shared cross-cutting UI modules
│   │   │   ├── router/         # GoRouter definitions & route guards
│   │   │   ├── theme/          # Neumorphic design tokens, theme controller & color presets
│   │   │   ├── utils/          # Formatting & category icon utilities
│   │   │   └── widgets/        # Reusable components (AppNavBar, BreadcrumbBadge, SnackBar)
│   │   └── features/           # Feature-first screen modules
│   │       ├── ai_assistant/   # Financial AI chat & spending queries
│   │       ├── auth/           # Login, Sign Up, and Password Reset screens
│   │       ├── customization/  # Theme, color presets & font scaling (S, M, L, XL)
│   │       ├── dashboard/      # Spending metrics, line charts & scan CTA
│   │       ├── developer_tools/# Isar database inspector (gated by APP_ENV=development)
│   │       ├── history/        # Filterable transaction ledger & category drill-down
│   │       ├── legal/          # Markdown viewer for terms, privacy & cookies
│   │       ├── receipt_detail/ # Itemized transaction viewer & line item editor
│   │       ├── scanner/        # Camera capture, OCR parser & verification review
│   │       ├── settings/       # Settings, feedback dialog, export & account view
│   │       └── splash/         # Animated startup splash screen
│   └── main.dart               # Application entrypoint & ProviderScope root
├── test/                       # Comprehensive Automated Test Suite (115+ Tests)
│   ├── services/               # API & OCR service integration tests
│   └── unit/                   # Unit & widget tests covering all domains & screens
├── pubspec.yaml                # Dependencies, assets & fonts configuration
└── README.md                   # Project index & quickstart guide
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
- The route table is defined declaratively inside [`lib/ui/core/router/app_router.dart`](file:///lib/ui/core/router/app_router.dart) as a Riverpod `Provider<GoRouter>` (`routerProvider`).
- Integrated into the app root via `MaterialApp.router` in [`lib/main.dart`](file:///lib/main.dart).

### Key Advantages of `go_router` Over Default Navigator:
- **Declarative & Path-Based**: Uses URL-style path strings (e.g., `/splash`, `/scanner`, `/dashboard`, `/receipt-detail`, `/settings`, `/customization`, `/db-viewer`).
- **Path Parameter Passing**: Supports typed parameters directly via route parameters (e.g., `state.pathParameters['id']`).
- **Riverpod Integration**: Route state reacts seamlessly to authentication, theme, or sync changes.
- **Deep Linking & Platform Support**: Ready for web browser URLs and mobile deep links out-of-the-box.
