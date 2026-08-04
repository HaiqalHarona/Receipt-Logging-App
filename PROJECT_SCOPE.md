# Receipt Logger — Project Scope & Architecture Blueprint

## Overview
Privacy-first, offline-first receipt and expense tracking mobile application built with Flutter, Riverpod 2.x, Isar 3.x, GoRouter, and a Neumorphic Design System (`flutter_neumorphic_plus`).

### Core Architecture & Workflow
```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                               Camera Image Capture / Picker                             │
└───────────────────────────────────────────┬─────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                 Backend REST Client: BackendApiClient.parseReceiptImage                 │
│ Header: X-Device-ID: "MB-12345"       (Required for all protected routes)              │
│ Header: X-Device-Token: "sec-token"   (Required — cryptographic hardware fingerprint)  │
│ Header: X-User-ID: "user-uuid"        (Optional verification header when signed in)     │
│ Endpoint: POST /api/v1/scan/parse     (Enforces 10MB ceiling, >=0.8 confidence score)   │
└───────────────────────────────────────────┬─────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                             Verification Review Modal (UI)                              │
│ Validate AI-extracted merchant name, line items, totals, date, and category inference │
└───────────────────────────────────────────┬─────────────────────────────────────────────┘
                                            │
                                            ▼
┌───────────────────────────────────────────┴─────────────────────────────────────────────┐
│                 Stateful UI Update + Isar 3.x Local Database Persistence                │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Primary Processing**: Camera capture sends raw image to the FastAPI backend (`POST /api/v1/scan/parse`) running Vision AI (Gemini 3.6 Flash) with a fixed JSON schema.
- **Rate Limit Handling (`HTTP 429`)**: `BackendApiClient` throws `RateLimitException` with `retryAfterSeconds` so UI screens can show live countdown timers and temporarily disable CTA buttons.
- **Offline Fallback Queue**: If offline during capture, raw images are stored locally with `isSynced = false` and automatically processed via `connectivity_plus` when network connectivity is restored.
- **Local Persistence**: Fast offline-first storage via Isar 3.x.

---

## 20-Endpoint Backend Matrix & Alignment Specifications

| # | Endpoint Route | HTTP Method | Rate Limit (req/min) | Header Requirements | Description & Frontend Client Integration |
|---|---|---|---|---|---|
| 1 | `/api/v1/health/` | `GET` | 120 | None | Health check & system status |
| 2 | `/api/v1/devices/register` | `POST` | 10 | None | `BackendApiClient.registerDevice` — Bootstrap device ID & token |
| 3 | `/api/v1/devices/me` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.fetchDeviceProfile` — Fetch current device registration |
| 4 | `/api/v1/devices/me` | `DELETE` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.deleteDeviceProfile` — Soft-delete device record |
| 5 | `/api/v1/devices/link` | `POST` | 10 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.linkDevice` — Link device to user or unlink (guest) |
| 6 | `/api/v1/user/create` | `POST` | 10 | None | `BackendApiClient.createUser` — Register new user account |
| 7 | `/api/v1/user/login` | `POST` | 10 | None | `BackendApiClient.loginUser` — Authenticate user credentials |
| 8 | `/api/v1/user/me` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.fetchUserProfile` — Fetch authenticated user profile |
| 9 | `/api/v1/user/me` | `DELETE` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.deleteUserProfile` — Soft-delete user profile |
| 10 | `/api/v1/scan/parse` | `POST` | 5 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.parseReceiptImage` — Gemini 3.6 Flash Vision OCR |
| 11 | `/api/v1/receipts/` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.fetchReceipts` — List session receipts |
| 12 | `/api/v1/receipts/{receipt_id}` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.getReceipt` — Get single receipt details |
| 13 | `/api/v1/receipts/create` | `POST` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.saveReceipt` — Persist single receipt |
| 14 | `/api/v1/receipts/batch` | `POST` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.saveReceiptBatch` — Batch persist up to 100 receipts |
| 15 | `/api/v1/receipts/{receipt_id}` | `DELETE` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.deleteReceipt` — Soft-delete receipt |
| 16 | `/api/v1/chat/create` | `POST` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.createConversation` — Create AI chat conversation |
| 17 | `/api/v1/chat/list` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.fetchConversations` — List active chat conversations |
| 18 | `/api/v1/chat/history` | `GET` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.fetchChatHistory` — Fetch paginated chat history |
| 19 | `/api/v1/chat/query` | `POST` | 10 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.sendChatQuery` — Send user query to RAG AI assistant |
| 20 | `/api/v1/chat/{conversation_id}` | `DELETE` | 60 | `X-Device-ID`, `X-Device-Token` | `BackendApiClient.deleteConversation` — Soft-delete conversation |

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
| 9 | **Paywall & Authentication** | Premium tier upgrade & cloud sync sign-in (`/user/create`, `/user/login`, `/devices/link`) | `/auth` | *Pending* |

---

## Active Target Routes (Rebuild Phase)

1. **Splash Screen** (`/splash`) — [splash_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/splash/views/splash_screen.dart)
2. **Scanner Screen** (`/scanner`) — [scanner_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/scanner/views/scanner_screen.dart)
3. **Dashboard Screen** (`/dashboard`) — [dashboard_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/dashboard/views/dashboard_screen.dart)
4. **Receipt Detail Screen** (`/dashboard/receipt/:id`) — [receipt_detail_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/receipt_detail/views/receipt_detail_screen.dart)
5. **Settings Screen** (`/settings`) — [settings_screen.dart](file:///C:/mobile-development/receipt_logging_app/lib/ui/features/settings/views/settings_screen.dart)
