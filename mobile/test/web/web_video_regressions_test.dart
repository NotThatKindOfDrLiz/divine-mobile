import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web index bootstraps sql.js for Drift web storage', () {
    final contents = File('web/index.html').readAsStringSync();

    expect(contents, contains('sql-wasm.js'));
    expect(contents, contains('initSqlJs'));
    expect(contents, contains('locateFile'));
    expect(contents, contains('pointer-events: none'));
  });

  test(
    'web video player blocks pointer input via CSS pointer-events',
    () {
      final contents = File(
        'lib/widgets/web_video_player_web.dart',
      ).readAsStringSync();

      expect(contents, contains('pointer-events'));
      expect(contents, contains('none'));
    },
  );

  test('web video player uses HtmlElementView not VideoPlayer', () {
    final contents = File(
      'lib/widgets/web_video_player_web.dart',
    ).readAsStringSync();

    expect(contents, contains('HtmlElementView'));
    expect(contents, isNot(contains('child: VideoPlayer(')));
  });

  test('web video player uses conditional imports', () {
    final contents = File(
      'lib/widgets/web_video_player.dart',
    ).readAsStringSync();

    expect(contents, contains('web_video_player_stub.dart'));
    expect(contents, contains('web_video_player_web.dart'));
  });
}
