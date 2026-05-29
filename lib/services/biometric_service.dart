// lib/services/biometric_service.dart

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEmail    = 'bio_email';
  static const _keyPassword = 'bio_password';
  static const _keyEnabled  = 'bio_enabled';

  // ── Check if device supports fingerprint / Face ID ─────────────────────────
  static Future<bool> isAvailable() async {
    try {
      final canCheck  = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      final enrolled  = await _auth.getAvailableBiometrics();
      final hasEnrolled = enrolled.isNotEmpty;

      print("canCheck: $canCheck, supported: $supported, enrolled: $enrolled");

      return canCheck && supported && hasEnrolled;
    } catch (e) {
      print("Availability error: $e");
      return false;
    }
  }

  // ── Check if user has previously enabled biometric login ───────────────────
  static Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _keyEnabled)) == 'true';
    } catch (_) {
      return false;
    }
  }

  // ── Show the OS fingerprint / Face ID prompt ───────────────────────────────
  static Future<bool> authenticate({
    String reason = 'Sign in to Gradex',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // false = also allows PIN as fallback
          stickyAuth: true,     // keeps prompt open if user switches apps
        ),
      );
    } catch (e) {
      if (e is PlatformException) {
        print("Biometric error code: ${e.code}, message: ${e.message}");
      } else {
        print("Biometric error: $e");
      }
      return false;
    }
  }

  // ── Save credentials securely after a successful normal login ──────────────
  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail,    value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled,  value: 'true');
  }

  // ── Retrieve saved credentials (only call after authenticate() = true) ─────
  static Future<({String? email, String? password})> getCredentials() async {
    try {
      final email    = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      return (email: email, password: password);
    } catch (_) {
      return (email: null, password: null);
    }
  }

  // ── Remove all stored credentials ─────────────────────────────────────────
  static Future<void> disable() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}