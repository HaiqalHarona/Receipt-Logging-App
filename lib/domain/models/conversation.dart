// lib/domain/models/conversation.dart
//
// Pure immutable domain model representing a chat conversation.
// Carries zero database or network dependencies.

import 'package:flutter/foundation.dart';

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete timestamp — null means the conversation is active.
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;

  // ── COPY HELPER ──────────────────────────────────────────────────────────────

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  // ── EQUALITY ─────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() =>
      'Conversation(id: $id, title: $title, updatedAt: $updatedAt)';
}
