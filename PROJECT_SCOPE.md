# Receipt Logger — Project Scope & Screen Audit

## Overview
Privacy-first receipt and expense tracking mobile application built with Flutter, Riverpod, Isar, and GoRouter.

---

## Planned Architecture Scope & Reference Image Mapping (9 Core Screens)

| # | Screen Name | Description & Core Logic | Reference Image File | Implementation Status |
|---|---|---|---|---|
| 1 | **Dashboard (Home)** | Spending summary metrics, weekly scan limit progress bar (4/10), recent entries, primary scan CTA | [dashboard-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/dashboard-screen.jpg) | **Implemented** (`/dashboard`) |
| 2 | **Camera / OCR Scanner** | Viewfinder, document edge-detection, live bounding boxes, image capture | [OCR_scanner-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/OCR_scanner-screen.jpg) | **Implemented** (`/scanner`) |
| 3 | **Data Verification (Review/Edit)** | Post-scan validation to edit OCR items, prices, merchant, and date before DB commit | [OCR_scanner-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/OCR_scanner-screen.jpg) *(Review Modal)* | *Pending* |
| 4 | **Receipt History / Ledger** | Searchable & filterable transaction ledger with itemized drill-down | [Receipt_History-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/Receipt_History-screen.jpg) | *Pending* |
| 5 | **Analytics & Comparison** | Spending trend charts, category breakdowns, price comparison over time | [Analytics-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/Analytics-screen.jpg) | *Pending* |
| 6 | **Paywall / Upgrade** | Unlocks unlimited scans, cloud backup, and RAG AI assistant | [paywall-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/paywall-screen.jpg) | *Pending* |
| 7 | **Authentication (Sign-up/Login)** | Post-paywall cloud sync sign-in (Google/Apple) | [auth-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/auth-screen.jpg) | *Pending* |
| 8 | **AI Assistant (RAG Chat)** | Conversational query interface over receipt database (locked overlay for free tier) | [AI_assistant-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/AI_assistant-screen.jpg) | *Pending* |
| 9 | **Settings & Data Management** | Export/wipe local data, subscription state, sync status | [settings-screen.jpg](file:///C:/Users/johan/Desktop/collab-projects/figma/Sanctum_Fundamentals/settings-screen.jpg) | **Implemented** (`/settings`) |

---

## Current Codebase Audit (5 Active Routes)

1. **Splash Screen** (`/splash`) — [splash_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/splash/splash_screen.dart)
2. **Scanner Screen** (`/scanner`) — [scanner_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/scanner/scanner_screen.dart)
3. **Dashboard Screen** (`/dashboard`) — [dashboard_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/dashboard/dashboard_screen.dart)
4. **Receipt Detail Screen** (`/dashboard/receipt/:id`) — [receipt_detail_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/receipt_detail/receipt_detail_screen.dart)
5. **Settings Screen** (`/settings`) — [settings_screen.dart](file:///C:/Users/johan/Desktop/collab-projects/reciept_logging/lib/screens/settings/settings_screen.dart)
