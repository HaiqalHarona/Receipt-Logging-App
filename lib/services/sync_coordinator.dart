// lib/services/sync_coordinator.dart
//
// Persistent offline-first Sync Coordinator for receipt_logging_app.
// Manages a persistent outbox mutation queue for receipts (create, update, delete)
// and automatically replays pending mutations when network connectivity is restored.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cloud/api/backend_api_client.dart';
import '../cloud/models/receipt_models.dart';
import '../cloud/services/auth_service.dart';
import 'app_logger_service.dart';

enum MutationAction { create, update, delete }

class SyncMutation {
  final String id;
  final String entityId;
  final MutationAction action;
  final Map<String, dynamic>? payload;
  final String? localImagePath;
  final DateTime createdAt;
  int retryCount;

  SyncMutation({
    required this.id,
    required this.entityId,
    required this.action,
    this.payload,
    this.localImagePath,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'action': action.name,
        'payload': payload,
        'localImagePath': localImagePath,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncMutation.fromJson(Map<String, dynamic> json) => SyncMutation(
        id: json['id'] as String,
        entityId: json['entityId'] as String,
        action: MutationAction.values.firstWhere(
          (e) => e.name == json['action'],
          orElse: () => MutationAction.create,
        ),
        payload: json['payload'] as Map<String, dynamic>?,
        localImagePath: json['localImagePath'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        retryCount: (json['retryCount'] as int?) ?? 0,
      );
}

class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator._();
  static final SyncCoordinator instance = SyncCoordinator._();

  static const String _outboxStorageKey = 'offline_sync_outbox_queue';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final List<SyncMutation> _outbox = [];
  bool _isProcessing = false;
  bool _isOnline = true;

  List<SyncMutation> get outbox => List.unmodifiable(_outbox);
  int get pendingCount => _outbox.length;
  bool get isProcessing => _isProcessing;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    await _loadOutbox();

    try {
      final initialResults = await _connectivity.checkConnectivity();
      _isOnline = initialResults.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _isOnline = true;
    }

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      AppLogger.info('SyncCoordinator',
          'Connectivity changed: isOnline=$hasConnection (pending=${_outbox.length})');
      _isOnline = hasConnection;
      notifyListeners();
      if (hasConnection && _outbox.isNotEmpty) {
        processOutbox();
      }
    });

    if (_isOnline && _outbox.isNotEmpty) {
      unawaited(processOutbox());
    }
  }

  Future<void> enqueueMutation({
    required String entityId,
    required MutationAction action,
    Map<String, dynamic>? payload,
    String? localImagePath,
  }) async {
    final mutation = SyncMutation(
      id: '${DateTime.now().millisecondsSinceEpoch}_$entityId',
      entityId: entityId,
      action: action,
      payload: payload,
      localImagePath: localImagePath,
      createdAt: DateTime.now(),
    );

    // If an update or delete arrives for an existing pending mutation, optimize the queue
    if (action == MutationAction.delete) {
      _outbox.removeWhere((m) => m.entityId == entityId);
    } else {
      _outbox.removeWhere((m) => m.entityId == entityId && m.action == action);
    }

    _outbox.add(mutation);
    await _persistOutbox();
    AppLogger.info('SyncCoordinator',
        'Enqueued mutation ${mutation.action.name} for $entityId. Total pending: ${_outbox.length}');
    notifyListeners();

    if (_isOnline) {
      unawaited(processOutbox());
    }
  }

  Future<void> processOutbox() async {
    if (_isProcessing || _outbox.isEmpty || !AuthService.instance.isLoggedIn) {
      return;
    }

    _isProcessing = true;
    notifyListeners();
    AppLogger.info(
        'SyncCoordinator', 'Processing ${_outbox.length} pending mutations...');

    final username = AuthService.instance.currentUsername;
    if (username == null) {
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final toProcess = List<SyncMutation>.from(_outbox);
    for (final mutation in toProcess) {
      try {
        await _executeMutation(mutation, username);
        _outbox.removeWhere((m) => m.id == mutation.id);
        await _persistOutbox();
        AppLogger.info('SyncCoordinator',
            'Successfully executed mutation ${mutation.id} (${mutation.action.name})');
      } catch (e) {
        mutation.retryCount += 1;
        AppLogger.warning('SyncCoordinator',
            'Mutation ${mutation.id} failed (attempt ${mutation.retryCount}): $e');
        if (mutation.retryCount >= 10) {
          AppLogger.error(
              'SyncCoordinator',
              'Dropping poisonous mutation ${mutation.id} after 10 failed attempts.',
              e);
          _outbox.removeWhere((m) => m.id == mutation.id);
          await _persistOutbox();
        }
        break; // Stop loop on network error to preserve execution order
      }
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _executeMutation(SyncMutation mutation, String username) async {
    switch (mutation.action) {
      case MutationAction.create:
        if (mutation.payload != null) {
          if (_isUuid(mutation.entityId)) {
            AppLogger.debug('SyncCoordinator',
                'Skipping create mutation for already-synced UUID ${mutation.entityId}');
            break;
          }
          final receiptDto = ReceiptDto.fromJson(mutation.payload!);
          List<int>? imageBytes;
          String? filename;
          if (mutation.localImagePath != null) {
            final file = File(mutation.localImagePath!);
            if (await file.exists()) {
              imageBytes = await file.readAsBytes();
              filename =
                  mutation.localImagePath!.split(Platform.pathSeparator).last;
            }
          }
          await BackendApiClient.instance.saveReceipt(
            receipt: receiptDto,
            username: username,
            imageBytes: imageBytes,
            filename: filename,
          );
        }
        break;

      case MutationAction.update:
        if (mutation.payload != null) {
          final receiptDto = ReceiptDto.fromJson(mutation.payload!);
          List<int>? imageBytes;
          String? filename;
          if (mutation.localImagePath != null) {
            final file = File(mutation.localImagePath!);
            if (await file.exists()) {
              imageBytes = await file.readAsBytes();
              filename =
                  mutation.localImagePath!.split(Platform.pathSeparator).last;
            }
          }
          await BackendApiClient.instance.updateReceipt(
            receiptId: mutation.entityId,
            receipt: receiptDto,
            username: username,
            imageBytes: imageBytes,
            filename: filename,
          );
        }
        break;

      case MutationAction.delete:
        await BackendApiClient.instance.deleteReceipt(
          receiptId: mutation.entityId,
          username: username,
        );
        break;
    }
  }

  Future<void> clearOutbox() async {
    _outbox.clear();
    await _persistOutbox();
    notifyListeners();
  }

  Future<void> _loadOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_outboxStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _outbox.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _outbox.add(SyncMutation.fromJson(item));
          }
        }
        AppLogger.info('SyncCoordinator',
            'Loaded ${_outbox.length} pending mutations from storage.');
      }
    } catch (e) {
      AppLogger.warning('SyncCoordinator', 'Failed to load outbox: $e');
    }
  }

  Future<void> _persistOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_outbox.map((m) => m.toJson()).toList());
      await prefs.setString(_outboxStorageKey, data);
    } catch (e) {
      AppLogger.warning('SyncCoordinator', 'Failed to persist outbox: $e');
    }
  }

  bool _isUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
