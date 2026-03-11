import 'package:bip39/bip39.dart' as bip39;
import 'package:nostr_sdk/nip19/nip19.dart';

/// Converts between private keys and 24-word backup phrases.
class KeyBackupWords {
  KeyBackupWords._();

  static bool isValidMnemonic(String words) {
    return bip39.validateMnemonic(_normalize(words));
  }

  static String nsecToMnemonic(String nsec) {
    if (!Nip19.isPrivateKey(nsec)) {
      throw ArgumentError('Invalid nsec format');
    }

    final privateKeyHex = Nip19.decode(nsec);
    return bip39.entropyToMnemonic(privateKeyHex);
  }

  static String mnemonicToNsec(String words) {
    final normalized = _normalize(words);
    if (!bip39.validateMnemonic(normalized)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final entropy = bip39.mnemonicToEntropy(normalized);
    if (entropy.length != 64) {
      throw ArgumentError('Mnemonic must encode a 32-byte private key');
    }

    return Nip19.encodePrivateKey(entropy);
  }

  static String _normalize(String words) {
    return words
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
  }
}
