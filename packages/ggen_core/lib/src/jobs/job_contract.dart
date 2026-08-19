import '../document/document_model.dart';

/// Every heavy operation declares finite admission limits before execution.
final class ResourceBudget {
  ResourceBudget({
    required this.maxMemoryBytes,
    required this.maxDiskBytes,
    required this.maxOutputCount,
    required this.maxConcurrency,
  }) {
    if (maxMemoryBytes < 1 || maxMemoryBytes > 1 << 50) {
      throw ArgumentError.value(
        maxMemoryBytes,
        'maxMemoryBytes',
        'Memory budget must be finite and positive.',
      );
    }
    if (maxDiskBytes < 1 || maxDiskBytes > 1 << 50) {
      throw ArgumentError.value(
        maxDiskBytes,
        'maxDiskBytes',
        'Disk budget must be finite and positive.',
      );
    }
    if (maxOutputCount < 1 || maxOutputCount > 1000000) {
      throw ArgumentError.value(
        maxOutputCount,
        'maxOutputCount',
        'Output count must be in 1..1,000,000.',
      );
    }
    if (maxConcurrency < 1 || maxConcurrency > 1024) {
      throw ArgumentError.value(
        maxConcurrency,
        'maxConcurrency',
        'Concurrency must be in 1..1024.',
      );
    }
  }

  final int maxMemoryBytes;
  final int maxDiskBytes;
  final int maxOutputCount;
  final int maxConcurrency;
}

final class JobProgress {
  JobProgress({
    required String phase,
    required this.completedUnits,
    required this.totalUnits,
  }) : phase = _phase(phase) {
    if (totalUnits < 1 || completedUnits < 0 || completedUnits > totalUnits) {
      throw ArgumentError(
        'Job progress must satisfy 0 <= completedUnits <= totalUnits.',
      );
    }
  }

  factory JobProgress.start() =>
      JobProgress(phase: 'starting', completedUnits: 0, totalUnits: 1);

  final String phase;
  final int completedUnits;
  final int totalUnits;

  double get fraction => completedUnits / totalUnits;
}

enum JobState {
  queued,
  admitted,
  running,
  pausing,
  paused,
  cancelling,
  cancelled,
  completed,
  partiallyCompleted,
  failed,
  recoveryRequired,
}

final class JobSnapshot {
  JobSnapshot.queued({
    required this.id,
    required String description,
    required this.budget,
  }) : description = _description(description),
       state = JobState.queued,
       progress = JobProgress.start(),
       failureCode = null;

  JobSnapshot._({
    required this.id,
    required this.description,
    required this.budget,
    required this.state,
    required this.progress,
    required this.failureCode,
  });

  final GgenId id;
  final String description;
  final ResourceBudget budget;
  final JobState state;
  final JobProgress progress;
  final String? failureCode;

  bool get isTerminal => <JobState>{
    JobState.cancelled,
    JobState.completed,
    JobState.partiallyCompleted,
    JobState.failed,
    JobState.recoveryRequired,
  }.contains(state);

  JobSnapshot transitionTo(
    JobState next, {
    JobProgress? progress,
    String? failureCode,
  }) {
    final allowed = _allowedTransitions[state] ?? const <JobState>{};
    final sameStateProgressUpdate = next == state && !isTerminal;
    if (!sameStateProgressUpdate && !allowed.contains(next)) {
      throw StateError('Invalid job transition: $state -> $next.');
    }
    final nextProgress = progress ?? this.progress;
    if (nextProgress.fraction < this.progress.fraction &&
        next != JobState.recoveryRequired) {
      throw StateError('Job progress cannot move backwards.');
    }
    if (next == JobState.completed && nextProgress.fraction < 1) {
      throw StateError(
        'A completed job must report one hundred percent progress.',
      );
    }
    if (next == JobState.failed || next == JobState.recoveryRequired) {
      final code = failureCode?.trim();
      if (code == null || code.isEmpty || code.length > 128) {
        throw ArgumentError(
          'A failed or recovery-required job needs a bounded failure code.',
        );
      }
      failureCode = code;
    } else if (failureCode != null) {
      throw ArgumentError('Failure code is only valid for failure states.');
    }
    return JobSnapshot._(
      id: id,
      description: description,
      budget: budget,
      state: next,
      progress: nextProgress,
      failureCode: failureCode,
    );
  }

  static const Map<JobState, Set<JobState>> _allowedTransitions =
      <JobState, Set<JobState>>{
        JobState.queued: <JobState>{
          JobState.admitted,
          JobState.cancelling,
          JobState.cancelled,
        },
        JobState.admitted: <JobState>{
          JobState.running,
          JobState.cancelling,
          JobState.cancelled,
          JobState.failed,
        },
        JobState.running: <JobState>{
          JobState.pausing,
          JobState.cancelling,
          JobState.completed,
          JobState.partiallyCompleted,
          JobState.failed,
          JobState.recoveryRequired,
        },
        JobState.pausing: <JobState>{
          JobState.paused,
          JobState.cancelling,
          JobState.failed,
        },
        JobState.paused: <JobState>{
          JobState.running,
          JobState.cancelling,
          JobState.recoveryRequired,
        },
        JobState.cancelling: <JobState>{
          JobState.cancelled,
          JobState.partiallyCompleted,
          JobState.failed,
        },
      };
}

/// Runtime adapters own queues, workers, checkpoints and resource admission.
abstract interface class ResourceBoundedJobRuntime {
  Future<JobSnapshot> submit(JobSnapshot queuedJob);

  Future<JobSnapshot> cancel(GgenId jobId);
}

String _description(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 256) {
    throw ArgumentError.value(
      value,
      'description',
      'Job description must contain 1..256 characters.',
    );
  }
  return normalized;
}

String _phase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(
      value,
      'phase',
      'Job phase must contain 1..128 characters.',
    );
  }
  return normalized;
}
