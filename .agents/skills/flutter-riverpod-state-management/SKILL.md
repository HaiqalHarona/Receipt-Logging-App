---
name: flutter-riverpod-state-management
description: Set up and use Riverpod with code generation (riverpod_annotation, riverpod_generator) for state management in Flutter. Covers AsyncNotifierProvider, StreamNotifierProvider, provider scoping, and testing.
metadata:
  version: "1.0.0"
---
# Flutter Riverpod State Management

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **Riverpod Annotation:** Utilizing `@riverpod` or `@Riverpod(keepAlive: true)` to automatically generate providers.
- **ProviderScope:** The widget that stores the state of providers. It must wrap the root of the app.
- **ConsumerWidget & ConsumerStatefulWidget:** Widgets that can listen to providers via `WidgetRef`.
- **AsyncNotifier:** Manages asynchronous state (loading, error, data).
- **Notifier:** Manages synchronous state.
- **Invalidation:** Using `ref.invalidate()` to clear a provider's state and force a refresh.
- **Family Providers:** Passing arguments to providers using code generation (simply by adding parameters to the build method).

## Workflow
### Task Progress
- [ ] Add dependencies (`flutter_riverpod`, `riverpod_annotation`) and dev_dependencies (`build_runner`, `riverpod_generator`, `custom_lint`, `riverpod_lint`).
- [ ] Wrap `runApp` with `ProviderScope`.
- [ ] Create a Notifier or AsyncNotifier using the `@riverpod` annotation.
- [ ] Run `dart run build_runner build -d` to generate the `.g.dart` file.
- [ ] Access the provider in a UI component using `ref.watch()`, `ref.read()`, or `ref.listen()`.

## Code Examples

### pubspec.yaml Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  riverpod_lint: ^2.3.2
  custom_lint: ^0.6.4
```

### ProviderScope Setup
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Riverpod App')),
      ),
    );
  }
}
```

### AsyncNotifierProvider Example
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_notifier.g.dart';

@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  FutureOr<String> build(String userId) async {
    // Family parameter `userId` is automatically supported
    return _fetchUser(userId);
  }

  Future<String> _fetchUser(String id) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'User $id';
  }

  Future<void> updateUser(String newName) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // simulate API call
      await Future.delayed(const Duration(seconds: 1));
      return newName;
    });
  }
}
```

### Watching in Widgets
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_notifier.dart';

class UserProfile extends ConsumerWidget {
  final String userId;
  
  const UserProfile({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userNotifierProvider(userId));

    return userAsync.when(
      data: (user) => Text('Name: $user'),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
```
