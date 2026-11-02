// ══════════════════════════════════════════════════════════
//  LEGAL LINKS  (Privacy Policy, Terms and Conditions, Delete Account)
//  Save as: lib/widgets/legal_links.dart
// ══════════════════════════════════════════════════════════

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'snackBar.dart';

class LegalUrls {
  static const String base = 'https://gradexapp.web.app';
  static const String privacy = '$base/privacy.html';
  static const String terms = '$base/terms.html';
  static const String deleteAccount = '$base/delete-account.html';
}

Future<void> openLegalUrl(BuildContext context, String url) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppSnackBar.showError(context, 'Could not open the link. Try again.');
  }
}

/// Text with tappable "Terms and Conditions" and "Privacy Policy" links.
/// [light] is true on a white background, false on the blue gradient.
class _LegalText extends StatefulWidget {
  final String prefix;
  final bool light;
  final double fontSize;
  final TextAlign textAlign;

  const _LegalText({
    required this.prefix,
    required this.light,
    required this.fontSize,
    required this.textAlign,
  });

  @override
  State<_LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<_LegalText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(context, LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(context, LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.light ? Colors.black54 : Colors.white70;
    final linkColor = widget.light ? const Color(0xFF1565C0) : Colors.white;

    final linkStyle = TextStyle(
      color: linkColor,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    return Text.rich(
      TextSpan(
        text: widget.prefix,
        style: TextStyle(color: textColor, fontSize: widget.fontSize, height: 1.45),
        children: [
          TextSpan(
            text: 'Terms and Conditions',
            style: linkStyle,
            recognizer: _termsTap,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}

/// "I agree to the Terms and Conditions and Privacy Policy" checkbox.
class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool light;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: light ? const Color(0xFF1565C0) : Colors.white,
            checkColor: light ? Colors.white : const Color(0xFF0D47A1),
            side: BorderSide(
              color: light ? Colors.black38 : Colors.white70,
              width: 1.6,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _LegalText(
              prefix: 'I agree to the ',
              light: light,
              fontSize: 13,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small centered line: "By continuing, you agree to our Terms ... and Privacy Policy."
/// Use it under Google sign-in buttons.
class LegalNotice extends StatelessWidget {
  final bool light;

  const LegalNotice({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    return _LegalText(
      prefix: 'By continuing, you agree to our ',
      light: light,
      fontSize: 12,
      textAlign: TextAlign.center,
    );
  }
}