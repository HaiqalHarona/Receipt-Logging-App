---
name: flutter-supabase-client-integration
description: Set up the supabase_flutter SDK for authentication (Google/Apple sign-in) and Storage bucket uploads. Covers initialization, auth state streams, and offline-safe usage alongside Isar.
metadata:
  version: "1.0.0"
---
# Flutter Supabase Client Integration

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **Supabase.initialize:** Required at app startup to configure URL and Anon Key.
- **GoTrueClient (`supabase.auth`):** Manages user authentication, supporting OAuth (Google, Apple) and email/password.
- **Storage (`supabase.storage`):** Handles uploading, downloading, and deleting files like receipt images.
- **Offline-First Fallback:** Since the app uses Isar, Supabase operations should degrade gracefully when offline (e.g., auth is optional for using the app locally).

## Workflow
### Task Progress
- [ ] Add `supabase_flutter` to `pubspec.yaml`.
- [ ] Call `Supabase.initialize()` in `main()`.
- [ ] Access the client via `Supabase.instance.client`.
- [ ] Implement OAuth sign-in logic using `signInWithOAuth`.
- [ ] Listen to auth state changes via `supabase.auth.onAuthStateChange`.
- [ ] Implement image upload to Supabase Storage.
- [ ] Get public URL or signed URL for downloaded images.

## Code Examples

### pubspec.yaml Dependencies
```yaml
dependencies:
  supabase_flutter: ^2.5.0
```

### Initialization
```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_ID.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

### Authentication with OAuth
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.receiptapp://login-callback/',
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;
}
```

### Listening to Auth State (e.g. in Riverpod)
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@riverpod
Stream<User?> authUser(AuthUserRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session?.user);
}
```

### Storage Bucket Uploads
```dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  Future<String?> uploadReceiptImage(File imageFile, String fileName) async {
    try {
      final String path = await _supabase.storage.from('receipts').upload(
        'public/$fileName',
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      // Get public URL
      final publicUrl = _supabase.storage.from('receipts').getPublicUrl('public/$fileName');
      return publicUrl;
    } on StorageException catch (e) {
      print('Supabase storage error: $e');
      return null;
    }
  }
}
```
