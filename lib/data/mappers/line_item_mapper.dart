// lib/data/mappers/line_item_mapper.dart
//
// Extension-based mappers for clean 3-way conversion:
//   LineItemIsarModel  <->  LineItem (domain)  <->  LineItemDto (API)

import '../../domain/models/line_item.dart';
import '../../services/api/api_models.dart';
import '../models/line_item_isar.dart';

// ── LineItemIsarModel → LineItem domain ──────────────────────────────────────

extension LineItemIsarToDomain on LineItemIsarModel {
  LineItem toDomain() => LineItem(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      );
}

// ── LineItem domain → LineItemIsarModel ──────────────────────────────────────

extension LineItemDomainToIsar on LineItem {
  LineItemIsarModel toIsar() => LineItemIsarModel(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      );
}

// ── LineItemDto → LineItem domain ────────────────────────────────────────────

extension LineItemDtoToDomain on LineItemDto {
  LineItem toDomain() => LineItem(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      );
}

// ── LineItem domain → LineItemDto ────────────────────────────────────────────

extension LineItemDomainToDto on LineItem {
  LineItemDto toDto() => LineItemDto(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      );
}
