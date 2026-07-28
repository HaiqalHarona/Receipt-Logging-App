# Receipt Logger — Project Structure & Architecture

## Overview
The **Receipt Logger** codebase follows Flutter architecture best practices, leveraging a **Feature-First / Layered Architecture** with **Riverpod 2.x** for state management, **Isar 3.x** for offline-first local storage, **flutter_neumorphic_plus** for the design system, and **GoRouter** for declarative navigation.

For full 9-screen project scope breakdown and implementation status, see [PROJECT_SCOPE.md](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/PROJECT_SCOPE.md).

---

## Complete Directory Breakdown

```
reciept_logging/
├── .agents/                    # Custom agentic skills & engineering standards
│   └── skills/                 # 28 specialized Flutter/Dart skills & guidelines
├── android/                    # Android native platform code & permissions config
├── ios/                        # iOS native platform runner & Info.plist permissions
├── lib/                        # Core Application Source Code
│   ├── core/                   # Shared cross-cutting application modules
│   │   ├── constants/          # App constants (strings, limits, defaults)
│   │   ├── providers/          # App-wide global Riverpod providers (e.g., Isar DB)
│   │   ├── router/             # GoRouter configuration & route definitions
│   │   ├── theme/              # Neumorphic design system token values & styles
│   │   └── widgets/            # Reusable core components (e.g., CategoryChip)
│   ├── database/               # Data access repositories (ReceiptRepository)
│   ├── models/                 # Isar data schemas (Receipt model & generated code)
│   ├── screens/                # Feature-first screen modules
│   │   ├── dashboard/          # Home dashboard & spending summaries
│   │   ├── receipt_detail/     # Itemized transaction detail view
│   │   ├── scanner/            # Camera preview & ML Kit OCR extraction screen
│   │   ├── settings/           # App settings & data management
│   │   └── splash/             # Initial animated splash screen
│   └── main.dart               # App entry point & ProviderScope root
├── test/                       # Unit and widget test suite
│   └── widget_test.dart        # Main widget smoke test
└── pubspec.yaml                # Package dependencies & asset configuration
```

---

## Why Each Screen Has Its Own Folder (Feature-First Architecture)

Each screen in `lib/screens/` resides in its own isolated folder (e.g., `lib/screens/scanner/`, `lib/screens/dashboard/`) for the following reasons:

1. **Encapsulation & Cohesion**:
   - All components, sub-widgets, local state controllers, and helper utilities specific to a screen remain strictly grouped within that screen's folder.
   - Prevents global shared directories (`lib/widgets/`) from becoming bloated with single-use widgets.

2. **Scalability & Feature Growth**:
   - When expanding a screen—such as adding a custom filter sheet to `dashboard/` or an editing modal to `scanner/`—new files can be placed alongside the parent screen without polluting unrelated features.

3. **Ease of Maintenance & Code Navigation**:
   - Developers can locate and refactor everything related to a single user view in one self-contained directory.

---

## Routing Strategy & Package

### Is it using default routing or an external package?
The app uses an **external package**: [`go_router`](https://pub.dev/packages/go_router) (`v14.8.1`).

### Implementation Details:
- The route table is defined declaratively inside [`lib/core/router/app_router.dart`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/core/router/app_router.dart) as a Riverpod `Provider<GoRouter>` (`routerProvider`).
- Integrated into the app root via `MaterialApp.router` in [`lib/main.dart`](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/main.dart#L26).

### Key Advantages of `go_router` Over Default Navigator:
- **Declarative & Path-Based**: Uses URL-style path strings (e.g., `/splash`, `/scanner`, `/dashboard`, `/dashboard/receipt/:id`).
- **Path Parameter Passing**: Supports typed parameters directly via route parameters (e.g., `state.pathParameters['id']`).
- **Riverpod Integration**: Route state can easily react to authentication or subscription changes.
- **Deep Linking & Platform Support**: Ready for web browser URLs and mobile deep links out-of-the-box.
