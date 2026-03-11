import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/key_backup_words.dart';

void main() {
  group('KeyBackupWords', () {
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    test('converts nsec to mnemonic and back to nsec', () {
      final mnemonic = KeyBackupWords.nsecToMnemonic(testNsec);

      expect(KeyBackupWords.isValidMnemonic(mnemonic), isTrue);

      final restoredNsec = KeyBackupWords.mnemonicToNsec(mnemonic);
      expect(restoredNsec, equals(testNsec));
    });

    test('rejects invalid mnemonic', () {
      expect(
        () => KeyBackupWords.mnemonicToNsec('not valid words'),
        throwsArgumentError,
      );
    });
  });
}
