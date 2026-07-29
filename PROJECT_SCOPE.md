# Receipt Logger — Project Scope & Architecture Blueprint

## Overview
Privacy-first, offline-first receipt and expense tracking mobile application built with Flutter, Riverpod 2.x, Isar 3.x, GoRouter, and a Neumorphic Design System (`flutter_neumorphic_plus`).

### Core Architecture & Workflow
```
[Camera Capture] --> [HTTP POST /parse-receipt] --> [Vision AI Backend (Gemini Flash)] --- (Structured JSON) --> [Verification Review Modal] --> [Stateful UI Update] --> [Isar Local DB]
```
- **Primary Processing**: Camera capture sends raw image to a backend API (or Supabase Edge Function) running Vision AI (Gemini Flash) with a fixed JSON schema.
- **Offline Fallback Queue**: If offline during capture, raw images are stored locally with `isSynced = false` and automatically processed via `connectivity_plus` when network connectivity is restored.
- **Local Persistence**: Fast offline-first storage via Isar 3.x.

---

## Planned Architecture Scope & Reference Image Mapping (9 Core Screens)

| # | Screen Name | Description & Core Logic | Route Path | Implementation Status |
|---|---|---|---|---|
| 1 | **Splash** | Animated Neumorphic logo & app initialization check | `/splash` | Planned |
| 2 | **Dashboard (Home)** | Spending summary metrics, weekly scan progress, recent entries, primary scan CTA | `/dashboard` | Planned |
| 3 | **Camera / Vision Scanner** | Viewfinder, image capture, API upload overlay, OCR status feedback | `/scanner` | Planned |
| 4 | **Data Verification (Review/Edit)** | Post-scan modal/screen to validate & edit AI-extracted items, merchant, and total before DB commit | Bottom sheet on `/scanner` | Planned |
| 5 | **Receipt Detail** | Itemized transaction breakdown, date/amount editor, and record deletion | `/dashboard/receipt/:id` | Planned |
| 6 | **Receipt History / Ledger** | Searchable & filterable transaction ledger with category drill-down | `/ledger` | *Pending* |
| 7 | **Analytics & Comparison** | Spending trend charts, category breakdowns, price comparison over time | `/analytics` | *Pending* |
| 8 | **Settings & Data Management** | Backend API URL config, light/dark Neumorphic theme toggle, local DB export & wipe | `/settings` | Planned |
| 9 | **Paywall & Authentication** | Premium tier upgrade & cloud sync sign-in (Google/Apple) | `/auth` | *Pending* |

---

## Active Target Routes (Rebuild Phase)

1. **Splash Screen** (`/splash`) — [splash_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/splash/views/splash_screen.dart)
2. **Scanner Screen** (`/scanner`) — [scanner_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/scanner/views/scanner_screen.dart)
3. **Dashboard Screen** (`/dashboard`) — [dashboard_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/dashboard/views/dashboard_screen.dart)
4. **Receipt Detail Screen** (`/dashboard/receipt/:id`) — [receipt_detail_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/receipt_detail/views/receipt_detail_screen.dart)
5. **Settings Screen** (`/settings`) — [settings_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/settings/views/settings_screen.dart)
