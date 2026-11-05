// lib/services/profile_sync.dart
//
// The app keeps a copy of the profile on the phone ("profile" in
// SharedPreferences) and many screens read it. The server is the truth: a
// session promotion moves everyone up a level there. This pulls the server's
// profile into the phone copy when the app starts and when it comes back to
// the front.
//
// An edit made while offline is never lost: the profile screen marks it as
// "not synced yet", and that edit is sent to the server first.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/studentProfile_model.dart';
import 'api_service.dart';

class ProfileSync {
  static bool _busy = false;

  /// Set by the profile screen when a save only reached the phone.
  static const unsyncedKey = 'profile_unsynced';

  static Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!await TokenStorage.hasTokens()) return;

      final prefs = await SharedPreferences.getInstance();

      // 1. An offline edit goes up first, so the server copy never wipes it.
      if (prefs.getBool(unsyncedKey) == true) {
        final raw = prefs.getString('profile');
        if (raw != null) {
          try {
            final local = StudentProfile.fromMap(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
            await ProfileService().updateProfile(local.toMap());
            await prefs.setBool(unsyncedKey, false);
          } on ApiException catch (e) {
            final code = e.statusCode;
            if (code != null && code >= 400 && code < 500) {
              // The server refused it (for example a class rep changing class).
              // The server's copy wins.
              await prefs.setBool(unsyncedKey, false);
            } else {
              return; // still offline: keep the phone copy for now
            }
          } catch (_) {
            return; // still offline
          }
        } else {
          await prefs.setBool(unsyncedKey, false);
        }
      }

      // 2. Pull the server's profile into the phone copy.
      final map = await ProfileService().getProfile();
      if ((map['school'] ?? '').toString().isEmpty) return; // odd state: leave it

      final profile = StudentProfile.fromMap(Map<String, dynamic>.from(map));
      final next = jsonEncode(profile.toMap());
      if (prefs.getString('profile') != next) {
        await prefs.setString('profile', next);
      }
    } catch (e) {
      debugPrint('ProfileSync.refresh: $e');
    } finally {
      _busy = false;
    }
  }
}