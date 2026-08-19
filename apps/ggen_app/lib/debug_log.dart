import 'dart:convert';

/// A bounded, exportable diagnostic log for field debugging.
///
/// Values are redacted before storage/export. Credentials, authorization
/// headers, cookies, and arbitrary long payloads must never enter a log.
class DebugLogStore {
  DebugLogStore({this.maxEntries = 500});

  final int maxEntries;
  final List<DebugLogEntry> _entries = <DebugLogEntry>[];

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

  void clear() => _entries.clear();

  void _add(String level, String event, String message, Map<String, Object?> details) {
    _entries.add(DebugLogEntry(
      timestampUtc: DateTime.now().toUtc(),
      level: level,
      event: event,
      message: _redact(message),
      details: _redactMap(details),
    ));
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

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
