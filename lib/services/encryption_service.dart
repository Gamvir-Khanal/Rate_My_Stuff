import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static final EncryptionService instance = EncryptionService._init();
  EncryptionService._init();

  final _secureStorage = const FlutterSecureStorage();
  static const String _keyStorageKey = 'history_master_encryption_key_v1';

  final Cipher _algorithm = Cryptography.instance.aesGcm();
  SecretKey? _cachedSecretKey;
  String? _cachedMasterKeyHex;

  /// Retrieves or generates a 256-bit master key hex string.
  /// Stored securely in OS KeyStore (Android) / Keychain (iOS) / Credential Manager (Windows).
  Future<String> getMasterKeyHex() async {
    if (_cachedMasterKeyHex != null) return _cachedMasterKeyHex!;

    try {
      String? keyHex = await _secureStorage.read(key: _keyStorageKey);
      if (keyHex == null || keyHex.isEmpty) {
        final secretKey = await _algorithm.newSecretKey();
        final bytes = await secretKey.extractBytes();
        keyHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await _secureStorage.write(key: _keyStorageKey, value: keyHex);
        debugPrint('🔐 Generated and stored new 256-bit encryption master key.');
      }
      _cachedMasterKeyHex = keyHex;
      return keyHex;
    } catch (e) {
      debugPrint('⚠️ Error reading/writing secure key storage: $e');
      rethrow;
    }
  }

  Future<SecretKey> _getSecretKey() async {
    if (_cachedSecretKey != null) return _cachedSecretKey!;
    final keyHex = await getMasterKeyHex();
    final bytes = Uint8List.fromList(
      List.generate(
        keyHex.length ~/ 2,
        (i) => int.parse(keyHex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
    _cachedSecretKey = SecretKey(bytes);
    return _cachedSecretKey!;
  }

  /// Encrypts raw bytes using AES-256-GCM.
  /// Payload format: [12 bytes Nonce] + [16 bytes MAC Tag] + [Ciphertext]
  Future<Uint8List> encryptBytes(Uint8List plainBytes) async {
    final secretKey = await _getSecretKey();
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final builder = BytesBuilder();
    builder.add(secretBox.nonce);
    builder.add(secretBox.mac.bytes);
    builder.add(secretBox.cipherText);
    return builder.toBytes();
  }

  /// Decrypts encrypted bytes using AES-256-GCM.
  Future<Uint8List> decryptBytes(Uint8List encryptedBytes) async {
    if (encryptedBytes.length < 28) {
      throw Exception('Invalid or corrupted encrypted payload.');
    }

    final nonce = encryptedBytes.sublist(0, 12);
    final macBytes = encryptedBytes.sublist(12, 28);
    final cipherText = encryptedBytes.sublist(28);

    final secretKey = await _getSecretKey();
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(clearBytes);
  }

  /// Encrypts a source file and writes the encrypted payload to [targetPath].
  Future<File> encryptAndSaveFile(File sourceFile, String targetPath) async {
    final plainBytes = await sourceFile.readAsBytes();
    final encryptedBytes = await encryptBytes(plainBytes);
    final targetFile = File(targetPath);
    return await targetFile.writeAsBytes(encryptedBytes, flush: true);
  }

  /// Reads an encrypted file from [filePath] and decrypts it into in-memory bytes.
  Future<Uint8List> readAndDecryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Encrypted file not found at: $filePath');
    }
    final encryptedBytes = await file.readAsBytes();
    return await decryptBytes(encryptedBytes);
  }
}
