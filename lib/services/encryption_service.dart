import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  final String _uid;
  EncryptionService(this._uid);

  String get _privKeyKey => '${_uid}_rsa_private_key';
  String get _pubKeyKey => '${_uid}_rsa_public_key';

  /// Generate RSA key pair and store private key in SharedPreferences
  Future<Map<String, dynamic>> generateKeyPair() async {
    final keyParams = pc.RSAKeyGeneratorParameters(
      BigInt.parse('65537'), 2048, 12,
    );

    final secureRandom = pc.FortunaRandom();
    final random = Random.secure();
    final seeds = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    secureRandom.seed(pc.KeyParameter(seeds));

    final rngParams = pc.ParametersWithRandom(keyParams, secureRandom);
    final generator = pc.RSAKeyGenerator()..init(rngParams);
    final pair = generator.generateKeyPair();

    final pubKey = pair.publicKey as pc.RSAPublicKey;
    final privKey = pair.privateKey as pc.RSAPrivateKey;

    final publicPem = _rsaPublicKeyToPem(pubKey);
    final privatePem = _rsaPrivateKeyToPem(privKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_privKeyKey, privatePem);
    await prefs.setString(_pubKeyKey, publicPem);

    return {'publicKey': publicPem, 'privateKey': privatePem};
  }

  /// Get stored private key
  Future<pc.RSAPrivateKey?> getPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final pem = prefs.getString(_privKeyKey);
    if (pem == null) return null;
    final parser = enc.RSAKeyParser();
    return parser.parse(pem) as pc.RSAPrivateKey;
  }

  /// Encrypt message for a specific recipient using their public key
  /// Returns "base64(RSA_encrypted_AES_key):base64Url(IV + AES_ciphertext)"
  Future<String> encryptMessage(String plainText, String recipientPublicKey) async {
    final parser = enc.RSAKeyParser();
    final publicKey = parser.parse(recipientPublicKey) as pc.RSAPublicKey;

    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);

    final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final encrypted = aesEncrypter.encrypt(plainText, iv: iv);

    final rsaEncrypter = enc.Encrypter(enc.RSA(publicKey: publicKey));
    final encryptedKey = rsaEncrypter.encrypt(base64.encode(aesKey.bytes));

    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length)
      ..setAll(0, iv.bytes)
      ..setAll(iv.bytes.length, encrypted.bytes);

    return '${encryptedKey.base64}:${base64Url.encode(combined)}';
  }

  /// Decrypt message using own private key
  Future<String> decryptMessage(String encryptedContent, String encryptedKey) async {
    final privKey = await getPrivateKey();
    if (privKey == null) {
      throw StateError('Private key not found for user $_uid');
    }

    final rsaDecrypter = enc.Encrypter(enc.RSA(privateKey: privKey));
    final aesKeyBase64 = rsaDecrypter.decrypt(enc.Encrypted.fromBase64(encryptedKey));
    final aesKey = enc.Key.fromBase64(aesKeyBase64);

    final combined = base64Url.decode(encryptedContent);
    if (combined.length < 16) {
      throw FormatException('Invalid encrypted content');
    }

    final iv = enc.IV(Uint8List.sublistView(combined, 0, 16));
    final ciphertext = enc.Encrypted(Uint8List.sublistView(combined, 16));

    final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    return aesEncrypter.decrypt(ciphertext, iv: iv);
  }

  /// Store public key in SharedPreferences
  Future<void> storePublicKey(String publicKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pubKeyKey, publicKey);
  }

  /// Get own public key
  Future<String?> getPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pubKeyKey);
  }

  String _rsaPublicKeyToPem(pc.RSAPublicKey key) {
    final seq = asn1.ASN1Sequence()
      ..add(asn1.ASN1Integer(key.modulus!))
      ..add(asn1.ASN1Integer(key.exponent!));
    return _toPem('RSA PUBLIC KEY', seq.encodedBytes);
  }

  String _rsaPrivateKeyToPem(pc.RSAPrivateKey key) {
    final dp = key.privateExponent! % (key.p! - BigInt.one);
    final dq = key.privateExponent! % (key.q! - BigInt.one);
    final iq = key.q!.modInverse(key.p!);

    final seq = asn1.ASN1Sequence()
      ..add(asn1.ASN1Integer(BigInt.zero))
      ..add(asn1.ASN1Integer(key.modulus!))
      ..add(asn1.ASN1Integer(BigInt.parse('65537')))
      ..add(asn1.ASN1Integer(key.privateExponent!))
      ..add(asn1.ASN1Integer(key.p!))
      ..add(asn1.ASN1Integer(key.q!))
      ..add(asn1.ASN1Integer(dp))
      ..add(asn1.ASN1Integer(dq))
      ..add(asn1.ASN1Integer(iq));
    return _toPem('RSA PRIVATE KEY', seq.encodedBytes);
  }

  String _toPem(String label, Uint8List der) {
    final b64 = base64.encode(der);
    final buf = StringBuffer()
      ..write('-----BEGIN $label-----\n');
    for (int i = 0; i < b64.length; i += 64) {
      buf.write(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
      buf.write('\n');
    }
    buf.write('-----END $label-----');
    return buf.toString();
  }
}
