# Receipt Logger — Data Flow & User Interaction Workflows

This document details how data flows across all layers of the Receipt Logger ecosystem—from user touchpoints on Flutter mobile/web clients down to the local Isar database, FastAPI backend, Redis job queue, Google Gemini 3.6 Flash Vision AI, and Supabase cloud persistence.

---

## 1. System Architecture & High-Level Topology

```mermaid
flowchart TB
    subgraph ClientLayer ["Client Layer (Flutter Mobile / Web)"]
        UI["Flutter Neumorphic UI / Views\n(Dashboard, Scanner, Verification, Chat)"]
        State["State Management & Repositories\n(Riverpod 2.x, ReceiptRepository)"]
        LocalDB[("Local Storage:\nIsar 3.x Database + SharedPreferences")]
        APIClient["BackendApiClient\n(HTTP Multipart / JSON / SSE)"]
    end

    subgraph GatewayLayer ["Backend Gateway (FastAPI on Port 8085)"]
        AuthMiddleware["Identity & Scoped Auth Middleware\n(Constant-Time Secret Verification)"]
        Routers["API v1 Routers\n(/scan, /receipts, /user, /devices, /chat)"]
    end

    subgraph ServiceLayer ["Async & AI Processing"]
        RedisQueue[("Redis Cache & Job Queue\n(TTL State & PubSub / SSE Polling)")]
        GeminiVision["Gemini 3.6 Flash Vision AI\n(Multimodal Schema Extraction)"]
        GeminiChat["Gemini 3.6 Flash Text\n(Financial RAG Inference)"]
    end

    subgraph CloudStorageLayer ["Cloud Persistence (Supabase)"]
        PostgresDB[("PostgreSQL Database\n(users, devices, receipts, conversations)")]
        VectorStore[("pgvector Embeddings\n(Semantic Financial Search)")]
    end

    %% Client Interactions
    UI --> State
    State <--> LocalDB
    State --> APIClient

    %% Client to Gateway
    APIClient -- "REST / SSE (X-Request-Type)" --> AuthMiddleware
    AuthMiddleware --> Routers

    %% Gateway to Services & Storage
    Routers <--> RedisQueue
    Routers <--> GeminiVision
    Routers <--> GeminiChat
    Routers <--> PostgresDB
    Routers <--> VectorStore
```

---

## 2. Core User Workflows & Data Flows

### Workflow 1: First Boot & Guest Mode Initialization
When a user launches the app for the first time without an account:

1. **Hardware Identity Generation**:
   - `DeviceIdentityService` generates a persistent UUID `deviceId` (e.g. `dev_a1b2c3d4...`) and a cryptographic random `deviceToken` (e.g. `token_e5f6a7b8...`).
   - These credentials are saved to local `SharedPreferences`.
2. **Device Registration with Backend**:
   - Client sends `POST /api/v1/devices/register` with `{"device_name": deviceId, "device_token": deviceToken}`.
   - Backend hashes the `device_token` with SHA-256 and stores the record in Supabase's `devices` table with `user_id = null`.
3. **Local Store Operation**:
   - All subsequent scans, categories, and spending transactions save immediately to local **Isar 3.x database**.
   - Guest requests to the backend (`/scan/*`, `/chat/query`) use `X-Request-Type: guest`, sending `X-Device-Name` and `X-Device-Token`.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Flutter Mobile App
    participant Prefs as SharedPreferences
    participant Backend as FastAPI Backend
    participant Supabase as Supabase DB

    User->>App: Launch App for First Time
    App->>Prefs: Check for stored deviceId / deviceToken
    Prefs-->>App: None found (First Boot)
    App->>App: Generate dev_<uuid> & token_<uuid>
    App->>Prefs: Persist deviceId & deviceToken
    App->>Backend: POST /api/v1/devices/register {device_name, device_token}
    Backend->>Backend: SHA-256 hash(device_token)
    Backend->>Supabase: INSERT INTO devices (name, device_token_hash, user_id=null)
    Supabase-->>Backend: Device Record Created (201)
    Backend-->>App: 201 Created (Device Record)
    App->>User: Display Dashboard (Guest Mode Ready)
```

---

### Workflow 2: Receipt Scanning & Structured AI Extraction

Users can scan receipts using two primary modes:

#### Mode A: Single Receipt Instant Scan
1. User taps the Camera Scanner CTA, snaps a photo, or selects an image from gallery.
2. Flutter reads image bytes and calls `BackendApiClient.parseReceiptImage()` (`POST /api/v1/scan/parse`).
3. Backend validates file size (max 10MB) and invokes Google Gemini 3.6 Flash Multimodal Vision (`ExtractionService`).
4. Gemini extracts structured fields (`merchant_name`, `line_items`, `tax_amount`, `total_amount`, `currency`, `category`, `confidence_score`, `raw_text`).
5. Backend verifies document validation score (`confidence_score >= 0.80`).
6. Backend returns `200 OK` with the parsed `Receipt` DTO.
7. Mobile client automatically pushes to `/verification` route, displaying pre-populated editable fields for user confirmation.

#### Mode B: Bulk Multi-Receipt Async Scan
1. User selects 2 to 10 receipts from gallery or camera batch mode.
2. Client sends `POST /api/v1/scan/parse-many` with the image files array.
3. Backend verifies batch bounds (2-10 files), registers a `batch_id` in Redis, schedules `process_receipt_worker` background tasks for each image, and returns `202 Accepted` with `batch_id`.
4. Client opens an SSE connection to `GET /api/v1/scan/parse-many/{batch_id}/stream`.
5. Background workers invoke Gemini in parallel and write completion states (`COMPLETED`/`FAILED`) and JSON results into Redis hashes.
6. When all tasks reach a terminal state, backend SSE stream emits `event: batch_complete` with the full array of extracted receipts.
7. Client UI closes the loader modal and presents the batch review deck.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Mobile Scanner UI
    participant API as FastAPI (/scan/parse-many)
    participant Redis as Redis Queue
    participant Worker as Background Task
    participant Gemini as Gemini 3.6 Flash
    participant SSE as SSE Stream Route

    User->>App: Select 3 Receipt Images & Tap "Process"
    App->>API: POST /api/v1/scan/parse-many (3 files, X-Request-Type: guest/user)
    API->>Redis: SADD batch:batch_id (job1, job2, job3)
    API->>Redis: HSET job:job_id (status=PENDING)
    API->>Worker: Dispatch worker for each image
    API-->>App: 202 Accepted (batch_id, job_ids)
    
    App->>SSE: GET /scan/parse-many/{batch_id}/stream
    
    par Async Processing
        Worker->>Redis: HSET job:job_id (status=PROCESSING)
        Worker->>Gemini: ExtractionService.extract_from_image()
        Gemini-->>Worker: Structured Receipt Schema
        Worker->>Redis: HSET job:job_id (status=COMPLETED, result=JSON)
    end

    SSE->>Redis: Check if all job_ids in batch are COMPLETED
    Redis-->>SSE: Yes (3/3 Completed)
    SSE-->>App: event: batch_complete {batch_id, jobs: [...parsed receipts...]}
    App->>User: Open Batch Verification Screen
```

---

### Workflow 3: Verification, Editing & Local Isar Persistence
1. User reviews the extracted merchant name, itemized line items, totals, date, and category.
2. User can tap any field to correct OCR mistakes or add custom line items.
3. Upon tapping "Confirm & Save":
   - Flutter creates an `ReceiptIsarModel` object.
   - Transaction is written atomically to local **Isar DB** (`ReceiptRepository.saveReceipt()`).
   - If user is logged in, a sync event is queued for remote cloud sync.
4. Dashboard and History tabs immediately update reactively via Riverpod state streams.

---

### Workflow 4: Financial AI Assistant & Spending Chat
The AI chat system supports dual storage architectures based on privacy preference and authentication status:

#### A. Local Store Mode (Guest or Offline User)
- User asks a financial question in `/ai-assistant` (e.g. *"How much did I spend on groceries this week?"*).
- Flutter queries local Isar DB for the top 50 recent receipts and gathers the last 20 chat turns.
- Client calls `POST /api/v1/chat/query` with `conversation_id = null`, sending `recent_receipts` and `conversation_history` in the request body.
- Backend passes these receipts as RAG context to Gemini 3.6 Flash.
- **Zero data is written to Supabase**.
- Backend returns synthetic UUIDs for user and assistant messages, which Flutter saves directly into local Isar DB (`ChatMessageIsarModel`).

#### B. Cloud Store Mode (Authenticated User)
- User selects an existing conversation or creates a new one (`POST /api/v1/chat/create`).
- Client calls `POST /api/v1/chat/query` with `conversation_id = <uuid>`.
- Backend fetches conversation history from Supabase, injects user's cloud receipts into Gemini context, and generates the analysis.
- Backend atomically inserts both user and assistant messages into Supabase's `chat_messages` table.

```mermaid
flowchart TD
    UserQuery["User submits question in AI Chat"] --> CheckMode{"Has conversation_id?"}

    subgraph LocalMode ["Local Store Mode (Zero Cloud Persistence)"]
        FetchIsar["Query local Isar DB for top 50 receipts + 20 history turns"]
        LocalReq["POST /api/v1/chat/query\n{conversation_id: null, recent_receipts, conversation_history}"]
        LocalGemini["Backend passes client receipts to Gemini"]
        LocalReturn["Backend returns synthetic message IDs"]
        LocalSave["Save ChatMessageIsarModel to local Isar DB"]
    end

    subgraph CloudMode ["Cloud Store Mode (Supabase Synchronized)"]
        CloudReq["POST /api/v1/chat/query\n{conversation_id: 'uuid...', message}"]
        CloudFetch["Backend fetches history & receipts from Supabase"]
        CloudGemini["Backend runs Gemini analysis"]
        CloudSave["Backend saves user & assistant rows to Supabase DB"]
    end

    CheckMode -- "No (Guest / Local)" --> FetchIsar --> LocalReq --> LocalGemini --> LocalReturn --> LocalSave
    CheckMode -- "Yes (Cloud Sync)" --> CloudReq --> CloudFetch --> CloudGemini --> CloudSave
```

---

### Workflow 5: Account Linking & Guest Data Cloud Migration
When a guest user decides to create an account or sign in:

1. **User Sign In**: User submits credentials via `POST /api/v1/user/login`.
2. **Local Data Export**: `DataExportService.exportGuestData()` serializes all local Isar receipts, conversations, and chat messages into a JSON migration package.
3. **Hardware & Data Linking**:
   - Client calls `POST /api/v1/devices/link` with:
     - Headers: `X-Device-Name`, `X-Device-Token`, `X-User-Name`, `X-User-Token`
     - Body: `{"device_name": deviceId, "username": username, "migrate_data": { receipts, conversations, chat_messages }}`
4. **Cloud Migration Engine**:
   - `DataMigrationService` runs a Supabase batch transaction:
     - Associates `device_id` with `user_id`.
     - Inserts all guest receipts into `receipts` table associated with `user_id`.
     - Inserts conversations and chat messages into Supabase.
5. **Local State Sync**:
   - Local Isar models are updated with cloud IDs and `is_synced = true`.

---

## 3. End-to-End Security & Header Validation Rules

```mermaid
flowchart LR
    Request["Incoming HTTP Request"] --> RouteCheck{"Route Type?"}

    RouteCheck -- "Public (/health, /user/login, /devices/register)" --> Allow["Execute Endpoint Handler"]
    
    RouteCheck -- "Device Scoped (/devices/me, /devices/rotate-token)" --> CheckDevHeaders["Verify X-Device-Name & X-Device-Token\n(SHA-256 Constant-Time Digest)"]
    
    RouteCheck -- "User Scoped (/user/me, /receipts/*, /chat/*)" --> CheckUserHeaders["Verify X-User-Name & X-User-Token\n(PBKDF2 Constant-Time Digest)"]

    RouteCheck -- "Dual Scoped (/scan/*, /chat/query)" --> CheckReqType{"X-Request-Type?"}
    
    CheckReqType -- "guest" --> DevOnly["Must have device headers.\nMust OMIT user headers."] --> CheckDevHeaders
    CheckReqType -- "user" --> UserOnly["Must have user headers.\nMust OMIT device headers."] --> CheckUserHeaders
    CheckReqType -- "other/missing" --> Reject400["HTTP 400 Bad Request"]

    CheckDevHeaders -- "Valid" --> Allow
    CheckDevHeaders -- "Invalid" --> Reject401["HTTP 401 Unauthorized"]
    
    CheckUserHeaders -- "Valid" --> Allow
    CheckUserHeaders -- "Invalid" --> Reject401
```

---

## 4. Summary Table of App Capabilities

| Feature Area | Client Technologies | Backend Services | Storage Strategy |
| :--- | :--- | :--- | :--- |
| **Receipt Scanning** | Camera, ImagePicker, ML Kit | FastAPI `/scan/parse`, Gemini 3.6 Flash Vision | In-memory stream, Redis async jobs |
| **Local Persistence** | Isar 3.x Database | None (Client-side) | On-device encrypted SQLite/Isar binary |
| **Cloud Synchronization** | Riverpod Sync Notifier, `BackendApiClient` | FastAPI `/receipts`, Supabase PostgreSQL | Delta timestamps (`updated_after`), batch inserts |
| **Financial AI Chat** | Markdown Renderer, Neumorphic Chat UI | FastAPI `/chat/query`, Gemini 3.6 Flash | Dual-Store (Isar for local, Supabase for cloud) |
| **Device Security** | `DeviceIdentityService`, `SharedPreferences` | `src/Auth/` constant-time digest verification | Hardware token hash in `devices` table |
