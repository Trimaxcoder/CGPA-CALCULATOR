// lib/widgets/personal_reminders_toggle.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class PersonalRemindersToggle extends StatefulWidget {
  const PersonalRemindersToggle({super.key});

  @override
  State<PersonalRemindersToggle> createState() => _PersonalRemindersToggleState();
}

class _PersonalRemindersToggleState extends State<PersonalRemindersToggle> {
  static const _prefKey = 'personal_reminders_enabled';
  bool _enabled = false;
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_prefKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Turning ON — check permission first
      final hasPermission = await NotificationService.canScheduleExactAlarms();
      if (!hasPermission) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permission needed'),
              content: const Text(
                'To send study reminders at the right time, GradeX needs permission to schedule exact alarms. Tap Continue to enable it.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    NotificationService.openExactAlarmSettings();
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        }
        return; // don't enable until permission confirmed
      }
    }

    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (value) {
      // Verification test — proves it works right now
      setState(() => _testing = true);
      await NotificationService.scheduleVerificationTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test reminder sent — check your notifications in 10 seconds!')),
        );
      }
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        _enabled ? Icons.alarm_on : Icons.alarm_off,
        color: _enabled ? const Color(0xFF1565C0) : Colors.grey,
      ),
      title: Text(
        'Personal Reminders',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(
        _enabled ? 'Bookmarked study sessions will remind you' : 'Bookmark reminders are off',
        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
      ),
      trailing: (_loading || _testing)
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Switch(
              value: _enabled,
              activeColor: const Color(0xFF1565C0),
              onChanged: _toggle,
            ),
    );
  }
}