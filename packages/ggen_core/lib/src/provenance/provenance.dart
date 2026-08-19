import '../document/document_model.dart';

enum LicenseReviewState { verified, pendingReview, blocked, unknown }

enum DistributionScope { publicRepository, privateVault, approvedOwnerWorkflow }

enum DistributionEligibility {
  eligible,
  privateOnly,
  blockedRights,
  blockedProvenance,
}

enum ProtectedAssetAvailability {
  unavailableNoPack,
  packPresentUnverified,
  packVerifiedPrivateOnly,
  availableForApprovedOwnerWorkflow,
  distributionBlockedRightsUnresolved,
}

/// A deliberately small SPDX expression validator.
///
/// The allow-list grows only when a license intake receipt is reviewed. This
/// prevents a typo or an invented identifier from being treated as a license.
/// Compound AND/OR expressions and LicenseRef identifiers are supported; SPDX
/// exception expressions are deferred until their intake rules are defined.
final class SpdxExpression {
  SpdxExpression(String value) : value = _validate(value);

  static const Set<String> _knownIdentifiers = <String>{
    '0BSD',
    'Apache-2.0',
    'BSD-2-Clause',
    'BSD-3-Clause',
    'CC0-1.0',
    'EPL-2.0',
    'GPL-2.0-only',
    'GPL-3.0-only',
    'ISC',
    'LGPL-2.1-only',
    'LGPL-3.0-only',
    'MIT',
    'MPL-2.0',
    'OFL-1.1',
    'Unlicense',
    'Zlib',
  };

  final String value;

  static String _validate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 256) {
      throw ArgumentError.value(
        value,
        'value',
        'SPDX expression must contain 1..256 characters.',
      );
    }

    final tokens = normalized
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    var expectsIdentifier = true;
    for (final token in tokens) {
      if (token == 'AND' || token == 'OR') {
        if (expectsIdentifier) {
          throw ArgumentError.value(
            value,
            'value',
            'SPDX operator cannot appear here.',
          );
        }
        expectsIdentifier = true;
        continue;
      }
      if (!expectsIdentifier || !_isIdentifier(token)) {
        throw ArgumentError.value(
          value,
          'value',
          'Unknown or misplaced SPDX identifier: $token.',
        );
      }
      expectsIdentifier = false;
    }
    if (expectsIdentifier) {
      throw ArgumentError.value(
        value,
        'value',
        'SPDX expression must end with an identifier.',
      );
    }
    return normalized;
  }

  static bool _isIdentifier(String value) =>
      _knownIdentifiers.contains(value) ||
      RegExp(r'^LicenseRef-[A-Za-z0-9.-]+$').hasMatch(value);

  @override
  bool operator ==(Object other) =>
      other is SpdxExpression && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class LicenseDescriptor {
  LicenseDescriptor({
    required this.reviewState,
    required String copyrightOwner,
    this.spdxExpression,
    this.licenseTextUrl,
    this.licenseTextSha256,
    this.ownerApprovedPrivateUse = false,
    this.redistributionAllowed = false,
    this.commercialUseAllowed = false,
    this.attributionRequired = false,
  }) : copyrightOwner = _requiredText(copyrightOwner, 'copyrightOwner') {
    if (spdxExpression == null && reviewState == LicenseReviewState.verified) {
      throw ArgumentError('A verified license requires an SPDX expression.');
    }
    if (licenseTextUrl != null && licenseTextUrl!.scheme != 'https') {
      throw ArgumentError.value(
        licenseTextUrl,
        'licenseTextUrl',
        'License evidence URLs must use HTTPS.',
      );
    }
    if (licenseTextSha256 != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(licenseTextSha256!)) {
      throw ArgumentError.value(
        licenseTextSha256,
        'licenseTextSha256',
        'License text digest must be a lowercase SHA-256 value.',
      );
    }
    if (redistributionAllowed && reviewState != LicenseReviewState.verified) {
      throw ArgumentError(
        'Redistribution cannot be allowed before license review is verified.',
      );
    }
    if (commercialUseAllowed && !redistributionAllowed) {
      throw ArgumentError(
        'Commercial use cannot be allowed without redistribution permission.',
      );
    }
  }

  final LicenseReviewState reviewState;
  final String copyrightOwner;
  final SpdxExpression? spdxExpression;
  final Uri? licenseTextUrl;
  final String? licenseTextSha256;
  final bool ownerApprovedPrivateUse;
  final bool redistributionAllowed;
  final bool commercialUseAllowed;
  final bool attributionRequired;

  DistributionEligibility eligibilityFor(
    DistributionScope scope, {
    required bool requiresPrivatePack,
  }) {
    if (scope == DistributionScope.publicRepository && requiresPrivatePack) {
      return DistributionEligibility.privateOnly;
    }
    if (reviewState == LicenseReviewState.unknown ||
        reviewState == LicenseReviewState.pendingReview) {
      return DistributionEligibility.blockedProvenance;
    }
    if (reviewState == LicenseReviewState.blocked ||
        !redistributionAllowed ||
        (scope == DistributionScope.publicRepository &&
            !commercialUseAllowed)) {
      return DistributionEligibility.blockedRights;
    }
    if (scope == DistributionScope.privateVault ||
        scope == DistributionScope.approvedOwnerWorkflow) {
      return ownerApprovedPrivateUse
          ? DistributionEligibility.eligible
          : DistributionEligibility.blockedRights;
    }
    return DistributionEligibility.eligible;
  }
}

final class SourceReceipt {
  SourceReceipt({
    required Uri sourceUrl,
    required String version,
    required String sourceCommit,
    required String sha256,
    required this.sizeBytes,
  }) : sourceUrl = _httpsUri(sourceUrl, 'sourceUrl'),
       version = _requiredText(version, 'version'),
       sourceCommit = _commit(sourceCommit),
       sha256 = _sha256(sha256) {
    if (sizeBytes < 1) {
      throw ArgumentError.value(
        sizeBytes,
        'sizeBytes',
        'A source receipt must describe at least one byte.',
      );
    }
  }

  final Uri sourceUrl;
  final String version;
  final String sourceCommit;
  final String sha256;
  final int sizeBytes;
}

final class AssetProvenance {
  AssetProvenance({
    required this.id,
    required String packPath,
    required String purpose,
    required this.source,
    required this.license,
    required this.requiredPrivatePack,
    required this.availability,
  }) : packPath = _relativePath(packPath),
       purpose = _requiredText(purpose, 'purpose');

  final GgenId id;
  final String packPath;
  final String purpose;
  final SourceReceipt source;
  final LicenseDescriptor license;
  final bool requiredPrivatePack;
  final ProtectedAssetAvailability availability;

  DistributionEligibility eligibilityFor(DistributionScope scope) =>
      license.eligibilityFor(scope, requiresPrivatePack: requiredPrivatePack);

  bool get canReadVerifiedBytes =>
      availability == ProtectedAssetAvailability.packVerifiedPrivateOnly ||
      availability ==
          ProtectedAssetAvailability.availableForApprovedOwnerWorkflow;
}

String _requiredText(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw ArgumentError.value(
      value,
      label,
      'Value must contain 1..512 non-whitespace characters.',
    );
  }
  return normalized;
}

Uri _httpsUri(Uri value, String label) {
  if (value.scheme != 'https' || value.host.isEmpty) {
    throw ArgumentError.value(
      value,
      label,
      'Source receipts require an HTTPS URL.',
    );
  }
  return value;
}

String _commit(String value) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'sourceCommit',
      'Source commit must be a 40-character lowercase Git SHA.',
    );
  }
  return value;
}

String _sha256(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'sha256',
      'SHA-256 must be a 64-character lowercase hexadecimal value.',
    );
  }
  return value;
}

String _relativePath(String value) {
  final normalized = value.trim();
  final path = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      path.any((String part) => part.isEmpty || part == '.' || part == '..') ||
      normalized.contains('\\') ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'packPath',
      'Pack path must be a canonical relative path.',
    );
  }
  return normalized;
}
