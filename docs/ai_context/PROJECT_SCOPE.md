# Receipt Logger — Project Scope and Architecture Blueprint

## Overview
Privacy-first, offline-first receipt and expense tracking mobile application built with Flutter, Riverpod 2.x, Isar 3.x, GoRouter, and a Neumorphic Design System (flutter_neumorphic_plus).

### Core Architecture and Workflow
```
+-----------------------------------------------------------------------------------------+
|                               Camera Image Capture / Picker                             |
+-------------------------------------------+---------------------------------------------+
                                            |
                                            v
+-----------------------------------------------------------------------------------------+
|                 Backend REST Client: BackendApiClient.parseReceiptImage                 |
| Header: X-Device-ID: "MB-12345"       (Required for all protected routes)              |
| Header: X-Device-Token: "sec-token"   (Required — cryptographic hardware fingerprint)  |
| Header: X-User-ID: "user-uuid"        (Optional verification header when signed in)     |
| Endpoint: POST /api/v1/scan/parse     (Enforces 10MB ceiling, >=0.8 confidence score)   |
+-------------------------------------------+---------------------------------------------+
                                            |
                                            v
+-----------------------------------------------------------------------------------------+
|                             Verification Review Modal (UI)                              |
| Validate AI-extracted merchant name, line items, totals, date, and category inference |
+-------------------------------------------+---------------------------------------------+
                                            |
                                            v
+-------------------------------------------+---------------------------------------------+
|                 Stateful UI Update + Isar 3.x Local Database Persistence                |
+-----------------------------------------------------------------------------------------+
```

- **Primary Processing**: Camera capture sends raw image to the FastAPI backend (`POST /api/v1/scan/parse`) running Vision AI (Gemini 3.6 Flash) with a fixed JSON schema.
- **Rate Limit Handling (HTTP 429)**: `BackendApiClient` throws `RateLimitException` with `retryAfterSeconds` so UI screens can show live countdown timers and temporarily disable CTA buttons.
- **Offline Fallback Queue**: If offline during capture, raw images are stored locally with `isSynced = false` and automatically processed via `connectivity_plus` when network connectivity is restored.
- **Local Persistence**: Fast offline-first storage via Isar 3.x.

---

## 20-Endpoint Backend Matrix and Alignment Specifications

| # | Endpoint Route | HTTP Method | Rate Limit (req/min) | Header Requirements | Description and Frontend Client Integration |
|---|---|---|---|---|---|
| 1 | `/api/v1/health/` | `GET` | 120 | None | Health check and system status |
| 2 | `/api/v1/devices/register` | `POST` | 10 | None | `BackendApiClient.registerDevice` — Bootstrap device ID and token |
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

## Active Screen Routes and Navigation Mapping

| # | Screen Name | Description and Core Logic | Route Path | Implementation Status |
|---|---|---|---|---|
| 1 | **Dashboard** | Spending summary metrics, monthly totals, category cards, recent entries | `/dashboard` (Shell Tab) | Active |
| 2 | **History** | Searchable and filterable transaction ledger with category drill-down | `/history` (Shell Tab) | Active |
| 3 | **AI Assistant** | Conversational receipt querying and spending insights chat interface | `/ai-assistant` (Shell Tab) | Active |
| 4 | **Settings** | Navigation hub for user profile, customization, DB viewer, and currency | `/settings` (Shell Tab) | Active |
| 5 | **Camera Scanner** | Fullscreen camera preview, image picker, and OCR trigger | `/scanner` | Active |
| 6 | **Data Verification** | Post-scan review and edit modal for AI-extracted merchant, items, and total | `/verification` | Active |
| 7 | **Receipt Detail** | Itemized receipt view, editing, and deletion | `/receipt-detail` | Active |
| 8 | **Analytics** | Spending charts, breakdown visualizers, and period comparisons | `/analytics` | Active |
| 9 | **Theme Customization** | Full-width preset slider, custom accent HSL sliders, Neumorphic depth | `/customization` | Active |
| 10 | **Database Viewer** | Raw local Isar database inspector and management | `/db-viewer` | Active |
| 11 | **User Settings** | Account profile management, cloud sync preferences, and session controls | `/user-settings` | Active |
| 12 | **Paywall** | Premium tier upgrade information and feature unlocking | `/paywall` | Active |
| 13 | **Auth Flow** | Login, signup, OTP verification, and password reset flows | `/auth`, `/login`, `/signup` | Active |
