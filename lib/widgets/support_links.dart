// ══════════════════════════════════════════════════════════
//  SUPPORT LINKS  (Help Center, Contact, WhatsApp, Report a bug, About)
//  Save as: lib/widgets/support_links.dart
// ══════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_links.dart';
import 'snackBar.dart';

class SupportInfo {
  static const String email = 'gradexapp1@gmail.com';
  static const String whatsappUrl = 'https://wa.me/2348107215725';
}

class SupportUrls {
  static const String about = '${LegalUrls.base}/about.html';
  static const String faq = '${LegalUrls.base}/faq.html';
  static const String contact = '${LegalUrls.base}/contact.html';
}

class SupportActions {
  /// Opens the user's email app with a message to support.
  /// If there is no email app, the support address is copied instead.
  static Future<void> emailSupport(
    BuildContext context, {
    String subject = 'SchoolLife support',
    String body = '',
  }) async {
    final uri = Uri.parse(
      'mailto:${SupportInfo.email}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: SupportInfo.email));
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'No email app found. Address copied: ${SupportInfo.email}',
        );
      }
    }
  }

  /// Email with the app version and platform already filled in.
  static Future<void> reportBug(
    BuildContext context, {
    required String appVersion,
  }) {
    final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    final body =
        'Please describe the problem or your feedback below.\n\n'
        'What happened:\n\n\n'
        'What you expected to happen:\n\n\n'
        '---\n'
        'App version: $appVersion\n'
        'Platform: $platform\n';
    return emailSupport(
      context,
      subject: 'SchoolLife bug report or feedback',
      body: body,
    );
  }

  /// Opens a WhatsApp chat with support.
  static Future<void> openWhatsApp(BuildContext context) {
    final text = Uri.encodeComponent('Hello SchoolLife support, ');
    return openLegalUrl(context, '${SupportInfo.whatsappUrl}?text=$text');
  }
}