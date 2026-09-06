import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A bounded, exportable diagnostic log for field debugging.
///
/// Values are redacted before storage/export. Credentials, authorization
/// headers, cookies, and arbitrary long payloads must never enter a log.
///
/// Additionally writes to a file in the app documents directory so it can be
/// read via `adb pull` for device validation without requiring the in-app
/// diagnostics dialog.
class DebugLogStore {
  DebugLogStore({this.maxEntries = 500});

  final int maxEntries;
  final List<DebugLogEntry> _entries = <DebugLogEntry>[];
  File? _logFile;

  /// Initialize persistent log file. Call once during app startup.
  Future<void> initLogFile() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _logFile = File('${docs.path}/debug_log.jsonl');
    } catch (e) {
      // Fall back to in-memory only
    }
  }

  void info(String event, String message, [Map<String, Object?> details = const {}]) =>
      _add('info', event, message, details);
  void warning(String event, String message, [Map<String, Object?> details = const {}]) =>
      _add('warning', event, message, details);
  void error(String event, String message, [Map<String, Object?> details = const {}]) =>
      _add('error', event, message, details);

  List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  String exportJson() => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema_version': 1,
        'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
        'entries': _entries.map((entry) => entry.toJson()).toList(),
      });

  void clear() {
    _entries.clear();
    _logFile?.deleteSync();
  }

  void _add(String level, String event, String message, Map<String, Object?> details) {
    final entry = DebugLogEntry(
      timestampUtc: DateTime.now().toUtc(),
      level: level,
      event: event,
      message: _redact(message),
      details: _redactMap(details),
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) _entries.removeAt(0);
    // Persist to file for ADB access
    _writeToFile(entry);
  }

  Future<void> _writeToFile(DebugLogEntry entry) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString('${const JsonEncoder().convert(entry.toJson())}\n', mode: FileMode.append);
    } catch (e) {
      // Ignore write errors
    }
  }

  /// Get path to debug log file for ADB pull
  String? get logFilePath => _logFile?.path;

  String _redact(String value) {
    final redacted = value.replaceAll(
      RegExp(r'(authorization|cookie|api[_-]?key|token|password)\s*[:=]\s*[^,;\s]+', caseSensitive: false),
      r'\$1=[REDACTED]',
    );
    return redacted.substring(0, redacted.length > 1000 ? 1000 : redacted.length);
  }

  Map<String, Object?> _redactMap(Map<String, Object?> source) => source.map(
        (key, value) => MapEntry(
          key,
          RegExp(r'(authorization|cookie|api[_-]?key|token|password|secret)', caseSensitive: false).hasMatch(key)
              ? '[REDACTED]'
              : value is String ? _redact(value) : value,
        ),
      );
}

class DebugLogEntry {
  const DebugLogEntry({required this.timestampUtc, required this.level, required this.event, required this.message, required this.details});
  final DateTime timestampUtc;
  final String level;
  final String event;
  final String message;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp_utc': timestampUtc.toIso8601String(),
        'level': level,
        'event': event,
        'message': message,
        if (details.isNotEmpty) 'details': details,
      };
}
