---
name: flutter-offline-first-sync
description: Implement an offline-first sync architecture where all data saves locally first (Isar) and syncs to the backend (FastAPI + Supabase) when online. Covers sync queue, connectivity detection, and conflict resolution.
metadata:
  version: "1.0.0"
---
# Flutter Offline-First Sync

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **Local Priority:** All creations, updates, and deletes are written to Isar immediately. The UI responds only to Isar data.
- **Sync Queue:** Records have an `isSynced` boolean flag and a `lastModified` timestamp. Records where `isSynced = false` form the sync queue.
- **Connectivity:** Using `connectivity_plus` to detect network status and trigger sync operations automatically.
- **Background/Timer Sync:** A `SyncService` that processes the queue either upon network restoration or periodically via Riverpod.
- **Conflict Resolution:** Last-write-wins is typically used for simple apps, driven by a `updatedAt` field.

## Workflow
### Task Progress
- [ ] Add `connectivity_plus` to `pubspec.yaml`.
- [ ] Create an Isar collection with `isSynced` and `updatedAt` fields.
- [ ] Implement a `SyncService` that fetches records where `isSynced == false`.
- [ ] Attempt to push changes via API/Supabase.
- [ ] Upon successful push, update the `isSynced` flag to `true` locally.
- [ ] Listen to network state changes using `Connectivity().onConnectivityChanged` and trigger sync.
- [ ] Handle API errors gracefully and apply exponential backoff.

## Code Examples

### pubspec.yaml Dependencies
```yaml
dependencies:
  connectivity_plus: ^6.0.3
```

### Sync Service Implementation
```dart
import 'package:isar/isar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'receipt.dart';
import 'api_client.dart'; // Your backend API or Supabase client

class SyncService {
  final Isar isar;
  final ApiClient apiClient;
  bool _isSyncing = false;

  SyncService({required this.isar, required this.apiClient}) {
    // Listen for network changes to trigger sync
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        syncPendingReceipts();
      }
    });
  }

  Future<void> syncPendingReceipts() async {
    if (_isSyncing) return;

    final pending = await isar.receipts.filter().isSyncedEqualTo(false).findAll();
    if (pending.isEmpty) return;

    _isSyncing = true;

    try {
      for (final receipt in pending) {
        // Optimistic push to backend
        final remoteId = await apiClient.pushReceipt(receipt);
        
        if (remoteId != null) {
          // Update local DB
          await isar.writeTxn(() async {
            receipt.isSynced = true;
            receipt.remoteId = remoteId;
            await isar.receipts.put(receipt);
          });
        }
      }
    } catch (e) {
      // Handle error, will retry on next sync pass
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
```

### Connecting SyncService to Riverpod
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'sync_service.dart';
import 'isar_provider.dart';
import 'api_client_provider.dart';

part 'sync_service_provider.g.dart';

@riverpod
SyncService syncService(SyncServiceRef ref) {
  final isar = ref.watch(isarInstanceProvider).requireValue;
  final apiClient = ref.watch(apiClientProvider);
  
  final service = SyncService(isar: isar, apiClient: apiClient);
  
  // Optional: Trigger a sync timer periodically
  // Timer.periodic(const Duration(minutes: 5), (_) => service.syncPendingReceipts());
  
  return service;
}
```
