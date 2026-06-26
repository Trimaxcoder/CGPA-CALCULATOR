import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class NotificationToggle extends StatefulWidget {
  const NotificationToggle({super.key});

  @override
  State<NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<NotificationToggle> {
  static const _prefKey = 'notifications_enabled';
  static const _baseUrl = 'https://gradexbackend.onrender.com/api';

  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_prefKey);
    setState(() {
      _enabled = cached ?? true;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    // Update UI and prefs immediately
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    try {
      final token = await TokenStorage.getAccessToken();

      final res = await http.patch(
        Uri.parse('$_baseUrl/notifications/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'enabled': value}),
      );

      if (res.statusCode != 200) {
        // Revert if backend failed
        setState(() => _enabled = !value);
        await prefs.setBool(_prefKey, !value);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update notification settings')),
          );
        }
      }
    } catch (_) {
      // Revert if no internet
      setState(() => _enabled = !value);
      await prefs.setBool(_prefKey, !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach server. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        _enabled ? Icons.notifications_active : Icons.notifications_off,
        color: _enabled ? const Color(0xFF1565C0) : Colors.grey,
      ),
      title: Text(
        'Push Notifications',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(
        _enabled ? 'You will receive class reminders' : 'All push notifications are off',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
      trailing: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: _enabled,
              activeColor: const Color(0xFF1565C0),
              onChanged: _toggle,
            ),
    );
  }
}