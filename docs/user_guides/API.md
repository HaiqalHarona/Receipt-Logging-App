# Receipt Logger Backend — API Specification

An AI-powered FastAPI backend service for receipt scanning, structured data extraction using Google Gemini 3.6 Flash Vision AI, session-scoped identity security, and cloud database synchronization for the Receipt Logger mobile application.

---

## Application Summary

The **Receipt Logger Backend** provides high-speed, intelligent multimodal receipt parsing and data management for the privacy-first mobile client. It accepts receipt image uploads, processes them asynchronously with Gemini 3.6 Flash Vision AI using strict structured Pydantic schemas, and manages batch parsing jobs in Redis with real-time Server-Sent Events (SSE) streaming updates. It also provides a full set of session-scoped CRUD endpoints for storing and managing receipts in Supabase with cryptographic device fingerprint verification (`X-Device-Token`) and scoped authentication (`X-Request-Type`).

### Key Technology Stack
- **Framework**: FastAPI (Python 3.10+) with Uvicorn ASGI server
- **Auth & Security**: `src/Auth/` package (`Identity` model, `X-Request-Type` scoped identity, `X-Device-Token` verification via constant-time `secrets.compare_digest`)
- **AI Extraction**: `google-genai` SDK (`gemini-3.6-flash` Multimodal Vision)
- **Job Queue & Caching**: Redis (Async Job Storage & TTL state management)
- **Data Validation**: Pydantic v2 schemas (`Receipt`, `LineItem`, `ScanResponse`, `BulkJobCreateResponse`, `BulkBatchStatusResponse`, `ReceiptRecord`, `UserRecord`, `DeviceRecord`)
- **Cloud Database & Storage**: Supabase (`supabase-py` `AsyncClient`) for Postgres DB, Storage, and Vector search
- **Architecture**: Layered Architecture with per-model repository pattern (`src/Models/Receipts/`, `src/Models/Users/`, `src/Models/Devices/`)
- **Configuration**: Pydantic `BaseSettings` and `python-dotenv`

---

## Features Breakdown

### Implemented Features
- **Device Registration & Token Management** (`/api/v1/devices`):
  - `POST /api/v1/devices/register`: Idempotent registration of hardware `device_id` and secret `device_token`.
  - `GET /api/v1/devices/me`: Retrieves current device registration record.
  - `POST /api/v1/devices/link`: Links/unlinks current device to a user account.
  - `POST /api/v1/devices/rotate-token`: Rotates device security token.
  - `DELETE /api/v1/devices/me`: Soft-deletes device record.
- **User Authentication & Password Management** (`/api/v1/user`):
  - `POST /api/v1/user/create`: Registers a new user account (PBKDF2/SHA-256 server-side password hash).
  - `POST /api/v1/user/login`: Authenticates credentials in constant time to prevent timing attacks.
  - `GET /api/v1/user/me`: Retrieves authenticated user profile (session-scoped).
  - `POST /api/v1/user/reset-password-initiate`: Initiates password reset flow.
  - `POST /api/v1/user/reset-password-otp`: Verifies OTP reset code.
  - `POST /api/v1/user/password-reset-new`: Sets new password following verification.
  - `DELETE /api/v1/user/me`: Soft-deletes user account profile.
- **Async Bulk Receipt Extraction & Streaming** (`/api/v1/scan`):
  - `POST /api/v1/scan/parse-many`: Accepts 1 to 10 receipt image files (`multipart/form-data`), enqueues background processing jobs, and returns `batch_id`.
  - `GET /api/v1/scan/parse-many/{batch_id}`: Retrieves job status (`PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`) and extracted JSON results (enforces batch ownership).
  - `GET /api/v1/scan/parse-many/{batch_id}/stream`: Real-time SSE stream emitting `progress` (`completed_jobs`/`total_jobs`) and `batch_complete` JSON events when extraction finishes (supports User & Guest modes).
  - `POST /api/v1/scan/parse` (`[DEPRECATED]`): Legacy synchronous single receipt parse endpoint.
- **Session-Scoped Receipt CRUD Endpoints** (`/api/v1/receipts`):
  - `GET /api/v1/receipts/`: Retrieves all non-deleted receipts owned by session identity (user or guest device).
  - `GET /api/v1/receipts/{receipt_id}`: Retrieves a single receipt by UUID, enforcing session ownership.
  - `POST /api/v1/receipts/`: Creates a single receipt record bound to session identity.
  - `POST /api/v1/receipts/batch`: Batch-creates up to 100 receipts bound to session identity in a single Supabase call.
  - `DELETE /api/v1/receipts/{receipt_id}`: Soft-deletes a receipt by setting `deleted_at` timestamp.
- **AI Financial Chat & Assistant** (`/api/v1/chat`):
  - `POST /api/v1/chat/create`: Starts a new financial assistant conversation.
  - `GET /api/v1/chat/list`: Lists active user conversations.
  - `GET /api/v1/chat/history`: Retrieves chat message history.
  - `POST /api/v1/chat/query`: Sends user query to Gemini 3.6 Flash with RAG receipt context.
  - `DELETE /api/v1/chat/{conversation_id}`: Soft-deletes conversation.
- **Explicit HTTP 422 Error Handling**: Custom exception handlers in `main.py` intercept any request payload schema mismatches or invalid data types and return clean `HTTP 422 Unprocessable Entity` responses.
- **Health Check and Diagnostics** (`GET /api/v1/health/`): Returns API operational status and environment setting.

---

## 🛠️ Scoped Header Authentication Contract

All protected endpoints enforce **Scoped Identity Authentication** (`get_scoped_identity` / `get_sse_identity`):

| Header Name | Type | Required Mode | Description |
|---|---|---|---|
| `X-Request-Type` | `string` | **Yes** | Scoped request mode: `'guest'` or `'user'`. |
| `X-Device-Name` / `X-Device-ID` | `string` | Required for `guest` mode | Unique hardware device identifier. |
| `X-Device-Token` | `string` | Required for `guest` mode | Cryptographic device fingerprint token. |
| `X-User-Name` / `X-User-ID` | `string` | Required for `user` mode | Authenticated user identity string. |
| `X-User-Token` | `string` | Required for `user` mode | Authenticated user secret password token. |

> [!NOTE]
> - `X-Request-Type: guest`: Requires device headers (`X-Device-Name`, `X-Device-Token`) and forbids user headers.
> - `X-Request-Type: user`: Requires user headers (`X-User-Name`, `X-User-Token`) and forbids device headers.
> - SSE Stream (`GET /parse-many/{batch_id}/stream`) supports both HTTP Headers and URL Query Parameters (`?username=...&user_token=...` or `?device_name=...&device_token=...`) for EventSource browser compatibility.

---

## 🏃 Running the Application

### Option A: Using the PowerShell Script (Recommended for Windows)

Run the included `run.ps1` script to start the server on port **8085**:

```powershell
.\run.ps1
```

---

### Option B: Manual Command Line

```bash
uvicorn main:app --host 0.0.0.0 --port 8085 --reload
```

---

## API Documentation and Interactive Docs

Once running, access the interactive API documentation at:
- **Swagger UI**: [http://localhost:8085/docs](http://localhost:8085/docs)
- **ReDoc**: [http://localhost:8085/redoc](http://localhost:8085/redoc)
- **OpenAPI Schema**: [http://localhost:8085/openapi.json](http://localhost:8085/openapi.json)
