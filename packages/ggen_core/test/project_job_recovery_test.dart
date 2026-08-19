import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  const sha256 =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  DocumentProject project({int revision = 0}) => DocumentProject(
    id: GgenId('project.storage'),
    name: 'Storage project',
    revision: revision,
  );

  ResourceBudget budget() => ResourceBudget(
    maxMemoryBytes: 1024,
    maxDiskBytes: 4096,
    maxOutputCount: 10,
    maxConcurrency: 1,
  );

  test('project schema envelope rejects mismatched versions', () {
    final envelope = ProjectEnvelope(
      project: project(),
      schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
    );
    expect(envelope.schemaVersion.isCurrent, isTrue);
    expect(
      () => ProjectEnvelope(
        project: project(),
        schemaVersion: ProjectSchemaVersion(2),
      ),
      throwsArgumentError,
    );
  });

  test('storage keys and receipts are path-free and content-addressed', () {
    expect(ProjectStorageKey('project.storage').value, 'project.storage');
    expect(() => ProjectStorageKey('../outside'), throwsArgumentError);
    final receipt = ProjectStoreReceipt(
      key: ProjectStorageKey('project.storage'),
      projectId: GgenId('project.storage'),
      committedRevision: 1,
      contentSha256: sha256,
      byteSize: 32,
    );
    expect(receipt.committedRevision, 1);
    expect(
      () => ProjectStoreReceipt(
        key: ProjectStorageKey('project.storage'),
        projectId: GgenId('project.storage'),
        committedRevision: 1,
        contentSha256: 'not-a-digest',
        byteSize: 32,
      ),
      throwsArgumentError,
    );
  });

  test('resource budget rejects unbounded or empty limits', () {
    expect(budget().maxMemoryBytes, 1024);
    expect(
      () => ResourceBudget(
        maxMemoryBytes: 0,
        maxDiskBytes: 1,
        maxOutputCount: 1,
        maxConcurrency: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ResourceBudget(
        maxMemoryBytes: 1,
        maxDiskBytes: 1,
        maxOutputCount: 1000001,
        maxConcurrency: 1,
      ),
      throwsArgumentError,
    );
  });

  test('job transitions are explicit, bounded and monotonic', () {
    final queued = JobSnapshot.queued(
      id: GgenId('job.export'),
      description: 'Export project',
      budget: budget(),
    );
    final running = queued
        .transitionTo(JobState.admitted)
        .transitionTo(JobState.running)
        .transitionTo(
          JobState.running,
          progress: JobProgress(
            phase: 'render',
            completedUnits: 1,
            totalUnits: 2,
          ),
        );
    final completed = running.transitionTo(
      JobState.completed,
      progress: JobProgress(
        phase: 'complete',
        completedUnits: 2,
        totalUnits: 2,
      ),
    );
    expect(completed.isTerminal, isTrue);
    expect(completed.progress.fraction, 1);
    expect(() => completed.transitionTo(JobState.running), throwsStateError);
    expect(
      () => running.transitionTo(
        JobState.completed,
        progress: JobProgress(
          phase: 'not finished',
          completedUnits: 1,
          totalUnits: 2,
        ),
      ),
      throwsStateError,
    );
    expect(
      () => running.transitionTo(
        JobState.running,
        progress: JobProgress(
          phase: 'backwards',
          completedUnits: 0,
          totalUnits: 2,
        ),
      ),
      throwsStateError,
    );
  });

  test('failure and recovery states require bounded codes', () {
    final running = JobSnapshot.queued(
      id: GgenId('job.recovery'),
      description: 'Recover project',
      budget: budget(),
    ).transitionTo(JobState.admitted).transitionTo(JobState.running);
    final failed = running.transitionTo(
      JobState.failed,
      failureCode: 'disk-full',
    );
    expect(failed.failureCode, 'disk-full');
    expect(
      () => running.transitionTo(JobState.recoveryRequired),
      throwsArgumentError,
    );
  });

  test('recovery journal records and autosave policy are bounded', () {
    final policy = AutosavePolicy(
      maxJournalEntries: 100,
      maxJournalBytes: 4096,
      checkpointEveryTransactions: 10,
    );
    expect(policy.checkpointEveryTransactions, 10);
    final record = RecoveryJournalRecord(
      id: GgenId('journal.entry'),
      projectId: GgenId('project.storage'),
      kind: RecoveryRecordKind.transaction,
      sequence: 1,
      baseRevision: 0,
      targetRevision: 1,
      payloadSha256: sha256,
      payloadBytes: 64,
    );
    expect(record.targetRevision, 1);
    expect(
      () => RecoveryJournalRecord(
        id: GgenId('journal.bad'),
        projectId: GgenId('project.storage'),
        kind: RecoveryRecordKind.transaction,
        sequence: 1,
        baseRevision: 2,
        targetRevision: 1,
        payloadSha256: sha256,
        payloadBytes: 64,
      ),
      throwsArgumentError,
    );
  });
}
