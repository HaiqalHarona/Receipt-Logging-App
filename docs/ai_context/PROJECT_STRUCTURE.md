# Receipt Logger — Project Structure and Architecture

## Overview
The Receipt Logger codebase follows Flutter architecture best practices, leveraging a Feature-First Layered Architecture with Riverpod 2.x for state management, Isar 3.x for offline-first local storage, flutter_neumorphic_plus for the design system, http/dio for Vision AI backend integration, and GoRouter for declarative navigation.

For the full scope breakdown and backend matrix, see [PROJECT_SCOPE.md](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/docs/ai_context/PROJECT_SCOPE.md).

---

## Complete Directory Breakdown

```
reciept_logging/
├── .agents/                    # Agentic skills and development instructions
├── .fvm/                       # Flutter Version Management pinned SDK (3.44.8)
├── .github/                    # GitHub Actions CI/CD workflows
│   └── workflows/
│       └── ci.yml              # Automated test, analyze, and build pipeline
├── android/                    # Android native platform code
├── ios/                        # iOS native platform runner
├── lib/                        # Core Application Source Code
│   ├── cloud/                  # Supabase auth and cloud integration services
│   │   └── services/           # AuthService, Supabase client wrapper
│   ├── data/                   # Data access layer
│   │   ├── models/             # Isar collection schemas (receipt, chat, conversation)
│   │   └── repositories/       # Local database repositories
│   ├── services/               # External network and device services
│   │   ├── api/                # FastAPI backend REST client and DTO schemas
│   │   ├── app_logger_service.dart     # Logging utility
│   │   ├── category_service.dart       # Expense categories and icon mapping
│   │   ├── cloud_sync_service.dart     # Remote cloud database sync
│   │   ├── currency_service.dart       # Multi-currency support and symbol formatting
│   │   ├── data_export_service.dart    # CSV and JSON data export
│   │   ├── device_identity_service.dart # Hardware device fingerprinting
│   │   ├── isar_service.dart           # Isar database singleton manager
│   │   └── ocr_service.dart            # ML Kit and Vision AI OCR orchestration
│   ├── ui/                     # UI Presentation layer
│   │   ├── core/               # Shared UI infrastructure
│   │   │   ├── config/         # Screen dimensions and app metadata
│   │   │   ├── router/         # GoRouter and MainTabShell definitions
│   │   │   ├── theme/          # Neumorphic tokens and AppThemeController
│   │   │   ├── utils/          # Formatting and UI helpers
│   │   │   └── widgets/        # Reusable Neumorphic widgets
│   │   └── features/           # Feature-first screens
│   │       ├── ai_assistant/   # Conversational expense query chat
│   │       ├── analytics/      # Spending breakdown charts
│   │       ├── auth/           # Login, signup, OTP, password reset
│   │       ├── dashboard/      # Spending overview, stats, recent entries
│   │       ├── history/        # Transaction ledger and filters
│   │       ├── paywall/        # Premium features and subscription view
│   │       ├── receipt_detail/ # Itemized transaction view and editor
│   │       ├── scanner/        # Camera preview and OCR trigger
│   │       ├── settings/       # Customization, DB viewer, user settings
│   │       └── verification/   # Post-scan OCR review and edit modal
│   └── main.dart               # Application entrypoint
├── docs/                       # Project Documentation
│   ├── ai_context/             # AI context and architecture blueprints
│   │   ├── PROJECT_SCOPE.md
│   │   └── PROJECT_STRUCTURE.md
│   └── user_guides/            # Developer and user guides
│       ├── AGENTS.md
│       ├── API.md
│       └── BRANCHING_AND_CICD.md
├── test/                       # Automated unit and widget tests
└── pubspec.yaml                # Project manifest and package dependencies
```

---

## Feature-First Architecture Principles

Each screen and domain capability in `lib/ui/features/` resides in its own isolated directory for the following reasons:

1. **Encapsulation and Cohesion**:
   - Views, sub-widgets, local state controllers, and helper utilities specific to a single user flow remain strictly grouped within that feature's directory.
   - Prevents global shared directories (`lib/ui/core/widgets/`) from becoming bloated with single-use components.

2. **Scalability and Feature Growth**:
   - When expanding a feature—such as adding a custom filter sheet to `dashboard/` or an editing modal to `scanner/`—new files are placed alongside the parent feature without polluting unrelated modules.

3. **Ease of Maintenance and Code Navigation**:
   - Developers and subagents can locate and refactor everything related to a single user view in one self-contained directory.

---

## Routing Strategy

The app utilizes declarative navigation with `go_router` (`v14.8.1`):
- **MainTabShell**: Implements a persistent Neumorphic bottom navigation bar housing the 4 primary tabs: `/dashboard`, `/history`, `/ai-assistant`, and `/settings`.
- **Standalone Modal and Sub-Routes**: Configured with custom Neumorphic page transitions for `/verification`, `/receipt-detail`, `/analytics`, `/customization`, `/db-viewer`, `/user-settings`, `/scanner`, `/paywall`, and `/auth`.
- **Authentication Guards**: Route redirect logic automatically routes unauthenticated users away from protected user settings and redirects logged-in users away from auth screens.
