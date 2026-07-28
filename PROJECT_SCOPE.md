# Receipt Logger — Project Scope & Screen Audit

## Overview
Privacy-first receipt and expense tracking mobile application built with Flutter, Riverpod, Isar, and GoRouter.

---

## Planned Architecture Scope: 9 Core Screens

| # | Screen Name | Description & Core Logic | Implementation Status |
|---|---|---|---|
| 1 | **Dashboard (Home)** | Spending summary metrics, weekly scan limit progress, recent entries, primary scan CTA | **Implemented** (`/dashboard`) |
| 2 | **Camera / OCR Scanner** | Viewfinder, document edge-detection, live bounding boxes, image capture | **Implemented** (`/scanner`) |
| 3 | **Data Verification (Review/Edit)** | Post-scan validation to edit OCR items, prices, merchant, and date before DB commit | *Pending* |
| 4 | **Receipt History / Ledger** | Searchable & filterable transaction ledger with itemized drill-down | *Pending* |
| 5 | **Analytics & Comparison** | Spending trend charts, category breakdowns, price comparison over time | *Pending* |
| 6 | **Paywall / Upgrade** | Unlocks unlimited scans, cloud backup, and RAG AI assistant | *Pending* |
| 7 | **Authentication (Sign-up/Login)** | Post-paywall cloud sync sign-in (Google/Apple) | *Pending* |
| 8 | **AI Assistant (RAG Chat)** | Conversational query interface over receipt database (locked overlay for free tier) | *Pending* |
| 9 | **Settings & Data Management** | Export/wipe local data, subscription state, sync status | **Implemented** (`/settings`) |

---

## Current Codebase Audit (5 Active Routes)

1. **Splash Screen** (`/splash`) — [splash_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/splash/splash_screen.dart)
2. **Scanner Screen** (`/scanner`) — [scanner_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/scanner/scanner_screen.dart)
3. **Dashboard Screen** (`/dashboard`) — [dashboard_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/dashboard/dashboard_screen.dart)
4. **Receipt Detail Screen** (`/dashboard/receipt/:id`) — [receipt_detail_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/receipt_detail/receipt_detail_screen.dart)
5. **Settings Screen** (`/settings`) — [settings_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/settings/settings_screen.dart)
