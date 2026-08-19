import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  const commit = '0123456789abcdef0123456789abcdef01234567';
  const sha256 =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  LicenseDescriptor verifiedLicense({bool ownerApprovedPrivateUse = true}) =>
      LicenseDescriptor(
        reviewState: LicenseReviewState.verified,
        copyrightOwner: 'GGEN owner',
        spdxExpression: SpdxExpression('Apache-2.0'),
        licenseTextUrl: Uri.parse('https://example.test/licenses/apache-2.0'),
        licenseTextSha256: sha256,
        ownerApprovedPrivateUse: ownerApprovedPrivateUse,
        redistributionAllowed: true,
        commercialUseAllowed: true,
      );

  SourceReceipt receipt() => SourceReceipt(
    sourceUrl: Uri.parse('https://example.test/ggen-assets'),
    version: 'v1',
    sourceCommit: commit,
    sha256: sha256,
    sizeBytes: 128,
  );

  test(
    'SPDX validator accepts reviewed identifiers and simple expressions',
    () {
      expect(SpdxExpression('Apache-2.0').value, 'Apache-2.0');
      expect(SpdxExpression('Apache-2.0 OR MIT').value, 'Apache-2.0 OR MIT');
      expect(
        SpdxExpression('LicenseRef-owner-approved').value,
        startsWith('LicenseRef-'),
      );
      expect(() => SpdxExpression('Invented-License'), throwsArgumentError);
      expect(() => SpdxExpression('Apache-2.0 OR'), throwsArgumentError);
    },
  );

  test('license descriptor blocks unreviewed redistribution', () {
    expect(
      verifiedLicense().eligibilityFor(
        DistributionScope.publicRepository,
        requiresPrivatePack: false,
      ),
      DistributionEligibility.eligible,
    );
    expect(
      () => LicenseDescriptor(
        reviewState: LicenseReviewState.pendingReview,
        copyrightOwner: 'Unknown owner',
        redistributionAllowed: true,
      ),
      throwsArgumentError,
    );
  });

  test('source receipt validates immutable URL, commit, digest and size', () {
    expect(receipt().sourceUrl.scheme, 'https');
    expect(receipt().sizeBytes, 128);
    expect(
      () => SourceReceipt(
        sourceUrl: Uri.parse('http://example.test/source'),
        version: 'v1',
        sourceCommit: commit,
        sha256: sha256,
        sizeBytes: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => SourceReceipt(
        sourceUrl: Uri.parse('https://example.test/source'),
        version: 'v1',
        sourceCommit: 'not-a-commit',
        sha256: sha256,
        sizeBytes: 1,
      ),
      throwsArgumentError,
    );
  });

  test('protected asset reports private-only eligibility and availability', () {
    final asset = AssetProvenance(
      id: GgenId('rgen.demo'),
      packPath: 'rgen/assets/demo.bin',
      purpose: 'owner-approved private test asset',
      source: receipt(),
      license: verifiedLicense(),
      requiredPrivatePack: true,
      availability: ProtectedAssetAvailability.packVerifiedPrivateOnly,
    );

    expect(
      asset.eligibilityFor(DistributionScope.publicRepository),
      DistributionEligibility.privateOnly,
    );
    expect(asset.canReadVerifiedBytes, isTrue);
    expect(
      asset.eligibilityFor(DistributionScope.approvedOwnerWorkflow),
      DistributionEligibility.eligible,
    );
  });

  test('canonical pack paths reject traversal and absolute names', () {
    expect(
      () => AssetProvenance(
        id: GgenId('asset.bad'),
        packPath: '../outside.bin',
        purpose: 'invalid',
        source: receipt(),
        license: verifiedLicense(),
        requiredPrivatePack: true,
        availability: ProtectedAssetAvailability.unavailableNoPack,
      ),
      throwsArgumentError,
    );
    expect(
      () => AssetProvenance(
        id: GgenId('asset.bad.absolute'),
        packPath: '/outside.bin',
        purpose: 'invalid',
        source: receipt(),
        license: verifiedLicense(),
        requiredPrivatePack: true,
        availability: ProtectedAssetAvailability.unavailableNoPack,
      ),
      throwsArgumentError,
    );
  });
}
