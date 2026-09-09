import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class LicenseService {
  static const String publicKeyBase64 =
      'dWSn3aI/iUic7K8IVZ2aRfZnhqSm/onF3JW20N+81HM=';

  static (String, String)? _parse(String fullKey) {
    final trimmed = fullKey.trim();
    final dot = trimmed.lastIndexOf('.');
    if (dot <= 0 || dot >= trimmed.length - 1) return null;
    return (trimmed.substring(0, dot).trim(), trimmed.substring(dot + 1).trim());
  }

  static String? extractIdentifier(String fullKey) => _parse(fullKey)?.$1;

  static Future<bool> verifyKey(String fullKey) async {
    try {
      final parsed = _parse(fullKey);
      if (parsed == null) return false;
      final (id, sig) = parsed;
      final sigBytes = base64Url.decode(base64Url.normalize(sig));
      final pubKey = SimplePublicKey(base64Decode(publicKeyBase64),
          type: KeyPairType.ed25519);
      return await Ed25519().verify(
        utf8.encode(id.toLowerCase()),
        signature: Signature(sigBytes, publicKey: pubKey),
      );
    } catch (_) {
      return false;
    }
  }
}
