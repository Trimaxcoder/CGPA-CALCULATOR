
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ui_helpers.dart';
import 'signinscreen.dart';
import '../widgets/snackBar.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _fk = GlobalKey<FormState>();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;
  bool _success = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(
        token: widget.token,
        newPassword: _passC.text.trim(),
      );
      if (mounted) setState(() => _success = true);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not connect. Check your internet and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.blue.shade300),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
    errorStyle: const TextStyle(color: Colors.redAccent),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          child: Form(
            key: _fk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacement(fadeRoute(const SignInScreen())),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 32),
                iconCircle(Icons.lock_outline_rounded, 76, 38),
                const SizedBox(height: 20),
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your new password below.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),

                if (!_success) ...[
                  // New password
                  TextFormField(
                    controller: _passC,
                    obscureText: _obscurePass,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Password is required';
                      if (v.trim().length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                    decoration: _dec('New Password', Icons.lock_outline)
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.blue.shade300,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmC,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please confirm your password';
                      if (v.trim() != _passC.text.trim())
                        return 'Passwords do not match';
                      return null;
                    },
                    decoration: _dec('Confirm Password', Icons.lock_outline)
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.blue.shade300,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: Colors.white38,
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.blue.shade700,
                              ),
                            )
                          : const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Success state
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Password Reset!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Your password has been successfully reset. You can now sign in with your new password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        fadeRoute(const SignInScreen()),
                        (_) => false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
