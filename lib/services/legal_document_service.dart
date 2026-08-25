import 'dart:io';
import 'package:flutter/services.dart';
import 'app_logger_service.dart';

enum LegalDocType {
  privacy,
  terms,
  cookies,
  accessibility;

  String get title {
    switch (this) {
      case LegalDocType.privacy:
        return 'Privacy Policy';
      case LegalDocType.terms:
        return 'Terms of Service';
      case LegalDocType.cookies:
        return 'Cookie & Storage Policy';
      case LegalDocType.accessibility:
        return 'Accessibility Statement';
    }
  }

  String get fileName {
    switch (this) {
      case LegalDocType.privacy:
        return 'PRIVACY_POLICY.md';
      case LegalDocType.terms:
        return 'TERMS_OF_SERVICE.md';
      case LegalDocType.cookies:
        return 'COOKIE_POLICY.md';
      case LegalDocType.accessibility:
        return 'ACCESSIBILITY_STATEMENT.md';
    }
  }

  String get assetPath => 'docs/legal_docs/$fileName';

  static LegalDocType fromString(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'privacy':
      case 'privacy_policy':
      case 'privacypolicy':
        return LegalDocType.privacy;
      case 'terms':
      case 'terms_of_service':
      case 'termsofservice':
      case 'tos':
        return LegalDocType.terms;
      case 'cookies':
      case 'cookie_policy':
      case 'cookiepolicy':
      case 'cookie':
        return LegalDocType.cookies;
      case 'accessibility':
      case 'accessibility_statement':
      case 'a11y':
        return LegalDocType.accessibility;
      default:
        return LegalDocType.privacy;
    }
  }
}

/// Service that reads and caches legal markdown documents from `docs/legal_docs/`.
class LegalDocumentService {
  LegalDocumentService._();
  static final LegalDocumentService instance = LegalDocumentService._();

  final Map<LegalDocType, String> _cache = {};

  /// Loads markdown content for [type] from Flutter assets or local filesystem.
  Future<String> loadDocument(LegalDocType type) async {
    if (_cache.containsKey(type)) {
      return _cache[type]!;
    }

    String? content;

    // 1. Try loading from Flutter asset bundle (docs/legal_docs/*.md)
    try {
      content = await rootBundle.loadString(type.assetPath);
      AppLogger.info('LegalDocumentService', 'Loaded ${type.name} from asset bundle: ${type.assetPath}');
    } catch (assetErr) {
      AppLogger.warning('LegalDocumentService', 'Could not load asset ${type.assetPath}: $assetErr');
    }

    // 2. Try loading directly from local filesystem (useful in development & testing)
    if (content == null || content.isEmpty) {
      try {
        final localFile = File(type.assetPath);
        if (await localFile.exists()) {
          content = await localFile.readAsString();
          AppLogger.info('LegalDocumentService', 'Loaded ${type.name} from local file: ${localFile.path}');
        }
      } catch (fileErr) {
        AppLogger.warning('LegalDocumentService', 'Could not load file ${type.assetPath}: $fileErr');
      }
    }

    // 3. Fallback message if file is completely unreachable
    if (content == null || content.isEmpty) {
      content = '# ${type.title}\n\n'
          'The document could not be loaded at this time. Please check your internet connection or visit https://receiptlogger.app/legal/${type.name}.\n\n'
          'For legal inquiries, contact **privacy@receiptlogger.app**.';
    }

    _cache[type] = content;
    return content;
  }

  /// Clears the in-memory cache.
  void clearCache() {
    _cache.clear();
  }
}
