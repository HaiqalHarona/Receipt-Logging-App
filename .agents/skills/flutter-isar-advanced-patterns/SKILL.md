---
name: flutter-isar-advanced-patterns
description: Advanced Isar patterns for reactive queries, watchers, sync flag management, and Riverpod integration. Covers stream-based UI updates and offline-first sync queue patterns.
metadata:
  version: "1.0.0"
---
# Flutter Isar Advanced Patterns

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **Reactive Streams:** Using `query.watch(fireImmediately: true)` to yield stream updates when data changes in Isar.
- **Sync Flag (`isSynced`):** A local field on Isar models indicating if the record has been pushed to the backend.
- **Composite Indexes:** Optimizing queries that filter and sort simultaneously (e.g., querying by category, ordered by date).
- **Riverpod Integration:** Wrapping Isar streams with `StreamNotifierProvider` or `StreamProvider` to create reactive UI.
- **Batch Writes:** Using `isar.writeTxn()` for atomic operations on multiple records.

## Workflow
### Task Progress
- [ ] Define the Isar collection with necessary indexes and an `isSynced` flag.
- [ ] Generate the Isar code using `dart run build_runner build`.
- [ ] Write a stream-based query using `.watch(fireImmediately: true)`.
- [ ] Integrate the stream into Riverpod to push data to the UI.
- [ ] Perform batch writes/updates inside a transaction block.

## Code Examples

### Isar Collection Definition
```dart
import 'package:isar/isar.dart';

part 'receipt.g.dart';

@collection
class Receipt {
  Id id = Isar.autoIncrement;

  String? remoteId;
  
  @Index(type: IndexType.value)
  late DateTime date;
  
  @Index(type: IndexType.hash)
  late String category;

  late double amount;

  // Composite index using date to order within a category
  @Index(composite: [CompositeIndex('date')])
  late String merchantName;

  @Index(type: IndexType.value)
  bool isSynced = false;
}
```

### Reactive Queries and Riverpod Integration
```dart
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'receipt.dart';
import 'isar_provider.dart'; // Assumes you have an Isar instance provider

part 'receipts_provider.g.dart';

@riverpod
Stream<List<Receipt>> unsyncedReceipts(UnsyncedReceiptsRef ref) async* {
  final isar = await ref.watch(isarInstanceProvider.future);
  
  yield* isar.receipts
      .filter()
      .isSyncedEqualTo(false)
      .sortByDateDesc()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Receipt>> categoryReceipts(CategoryReceiptsRef ref, String category) async* {
  final isar = await ref.watch(isarInstanceProvider.future);
  
  yield* isar.receipts
      .filter()
      .categoryEqualTo(category)
      .sortByDateDesc()
      .watch(fireImmediately: true);
}
```

### Batch Writes in Transactions
```dart
Future<void> markReceiptsAsSynced(Isar isar, List<Id> receiptIds, List<String> remoteIds) async {
  await isar.writeTxn(() async {
    for (int i = 0; i < receiptIds.length; i++) {
      final receipt = await isar.receipts.get(receiptIds[i]);
      if (receipt != null) {
        receipt.isSynced = true;
        receipt.remoteId = remoteIds[i];
        await isar.receipts.put(receipt);
      }
    }
  });
}
```
