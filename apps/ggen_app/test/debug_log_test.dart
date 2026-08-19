import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/debug_log.dart';

void main() {
  test('exports bounded redacted diagnostics', () {
    final logs = DebugLogStore(maxEntries: 2);
    logs.info('request', 'Authorization: Bearer secret', {'api_key': 'hidden', 'count': 1});
    logs.warning('second', 'safe');
    logs.error('third', 'also safe');

    final decoded = jsonDecode(logs.exportJson()) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>;
    expect(entries, hasLength(2));
    expect(logs.exportJson(), isNot(contains('secret')));
    expect(logs.exportJson(), isNot(contains('hidden')));
    expect(decoded['schema_version'], 1);
  });
}
