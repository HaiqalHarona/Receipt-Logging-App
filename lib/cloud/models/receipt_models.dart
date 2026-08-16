/// Dart DTO models for Receipt endpoints.
///
/// Covers:
///   POST   /api/v1/scan/parse-many  → [BulkJobCreateResponseDto]
///   GET    /api/v1/scan/parse-many/{batch_id} → [BulkBatchStatusResponseDto]
///   POST   /api/v1/scan/parse       → [ScanResponseDto] wrapping [ReceiptDto] [DEPRECATED]
///   POST   /api/v1/receipts/        → [ReceiptRecordDto]
///   POST   /api/v1/receipts/batch   → List<[ReceiptRecordDto]>
///   GET    /api/v1/receipts/        → List<[ReceiptRecordDto]>
///   DELETE /api/v1/receipts/{id}    → bool
library;

// ── LINE ITEM ──────────────────────────────────────────────────────────────────

class LineItemDto {
  const LineItemDto({
    required this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  final String description;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;

  factory LineItemDto.fromJson(Map<String, dynamic> json) {
    return LineItemDto(
      description: (json['description'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      totalPrice: (json['total_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (totalPrice != null) 'total_price': totalPrice,
      };
}

// ── RECEIPT ────────────────────────────────────────────────────────────────────

class ReceiptDto {
  const ReceiptDto({
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.rawText,
    this.lineItems = const [],
    this.subtotal,
    this.taxAmount,
    this.currency = 'USD',
    this.category,
    this.confidenceScore = 0.0,
    this.notes,
  });

  final String merchantName;
  final List<LineItemDto> lineItems;
  final double? subtotal;
  final double? taxAmount;
  final double totalAmount;
  final String currency;
  final String? category;
  final String date;          // ISO 8601 string
  final String rawText;
  final double confidenceScore;
  final String? notes;

  factory ReceiptDto.fromJson(Map<String, dynamic> json) {
    return ReceiptDto(
      merchantName: (json['merchant_name'] as String?) ?? 'Unknown Merchant',
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((e) => LineItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] as String?) ?? 'USD',
      category: json['category'] as String?,
      date: (json['date'] as String?) ?? DateTime.now().toIso8601String(),
      rawText: (json['raw_text'] as String?) ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_name': merchantName,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
        if (subtotal != null) 'subtotal': subtotal,
        if (taxAmount != null) 'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'currency': currency,
        if (category != null) 'category': category,
        'date': date,
        'raw_text': rawText,
        'confidence_score': confidenceScore,
        if (notes != null) 'notes': notes,
      };
}

// ── SCAN RESPONSE ─────────────────────────────────────────────────────────────

class ScanResponseDto {
  const ScanResponseDto({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final ReceiptDto? data;
  final String? error;

  factory ScanResponseDto.fromJson(Map<String, dynamic> json) {
    return ScanResponseDto(
      success: (json['success'] as bool?) ?? false,
      data: json['data'] != null
          ? ReceiptDto.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}

// ── BULK SCAN DTOs ─────────────────────────────────────────────────────────────

/// Mirrors BulkJobSummary — one entry in the POST /scan/parse-many response.
class BulkJobSummaryDto {
  const BulkJobSummaryDto({required this.jobId, this.filename});

  final String jobId;
  final String? filename;

  factory BulkJobSummaryDto.fromJson(Map<String, dynamic> json) {
    return BulkJobSummaryDto(
      jobId: (json['job_id'] as String?) ?? '',
      filename: json['filename'] as String?,
    );
  }
}

/// Mirrors BulkJobCreateResponse — the HTTP 202 body from POST /scan/parse-many.
class BulkJobCreateResponseDto {
  const BulkJobCreateResponseDto({
    required this.batchId,
    required this.totalJobs,
    required this.jobs,
  });

  final String batchId;
  final int totalJobs;
  final List<BulkJobSummaryDto> jobs;

  factory BulkJobCreateResponseDto.fromJson(Map<String, dynamic> json) {
    return BulkJobCreateResponseDto(
      batchId: (json['batch_id'] as String?) ?? '',
      totalJobs: (json['total_jobs'] as int?) ?? 0,
      jobs: (json['jobs'] as List<dynamic>?)
              ?.map((e) => BulkJobSummaryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Mirrors BulkJobStatus — per-job result inside GET /scan/parse-many/{batch_id}.
class BulkJobStatusDto {
  const BulkJobStatusDto({
    required this.jobId,
    required this.batchId,
    required this.status,
    this.filename,
    this.data,
    this.error,
  });

  final String jobId;
  final String batchId;
  final String? filename;
  /// One of: PENDING, PROCESSING, COMPLETED, FAILED
  final String status;
  final ReceiptDto? data;
  final String? error;

  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isTerminal => isCompleted || isFailed;

  factory BulkJobStatusDto.fromJson(Map<String, dynamic> json) {
    return BulkJobStatusDto(
      jobId: (json['job_id'] as String?) ?? '',
      batchId: (json['batch_id'] as String?) ?? '',
      filename: json['filename'] as String?,
      status: (json['status'] as String?) ?? 'PENDING',
      data: json['data'] != null
          ? ReceiptDto.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}

/// Mirrors BulkBatchStatusResponse — body from GET /scan/parse-many/{batch_id}
/// and the SSE `batch_complete` event data payload.
class BulkBatchStatusResponseDto {
  const BulkBatchStatusResponseDto({
    required this.batchId,
    required this.totalJobs,
    required this.completedJobs,
    required this.jobs,
  });

  final String batchId;
  final int totalJobs;
  final int completedJobs;
  final List<BulkJobStatusDto> jobs;

  bool get isAllDone => completedJobs >= totalJobs && totalJobs > 0;

  /// All successfully COMPLETED jobs with a non-null ReceiptDto.
  List<ReceiptDto> get successfulReceipts =>
      jobs.where((j) => j.isCompleted && j.data != null).map((j) => j.data!).toList();

  /// All successfully COMPLETED jobs retaining their job metadata (jobId, filename).
  List<BulkJobStatusDto> get completedJobsList =>
      jobs.where((j) => j.isCompleted && j.data != null).toList();

  /// All FAILED jobs (or completed jobs without valid data).
  List<BulkJobStatusDto> get failedJobsList =>
      jobs.where((j) => j.isFailed || (j.isCompleted && j.data == null)).toList();

  factory BulkBatchStatusResponseDto.fromJson(Map<String, dynamic> json) {
    return BulkBatchStatusResponseDto(
      batchId: (json['batch_id'] as String?) ?? '',
      totalJobs: (json['total_jobs'] as int?) ?? 0,
      completedJobs: (json['completed_jobs'] as int?) ?? 0,
      jobs: (json['jobs'] as List<dynamic>?)
              ?.map((e) => BulkJobStatusDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ── RECEIPT RECORD ────────────────────────────────────────────────────────────

class ReceiptRecordDto {
  const ReceiptRecordDto({
    required this.id,
    required this.deviceId,
    required this.receipt,
    required this.createdAt,
    this.userId,
    this.deletedAt,
  });

  final String id;
  final String? userId;
  final String deviceId;
  final ReceiptDto receipt;
  final String createdAt;
  final String? deletedAt;

  factory ReceiptRecordDto.fromJson(Map<String, dynamic> json) {
    return ReceiptRecordDto(
      id: (json['id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      deviceId: (json['device_id'] as String?) ?? '',
      receipt: ReceiptDto.fromJson(json['receipt'] as Map<String, dynamic>),
      createdAt: (json['created_at'] as String?) ?? '',
      deletedAt: json['deleted_at'] as String?,
    );
  }
}
