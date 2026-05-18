import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false, _sent = false;

  Future<void> _reset() async {
    if (_email.text.isEmpty || !_email.text.contains('@')) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).resetPassword(_email.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: BackButton(color: AppColors.textPrimary)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: _sent ? _sentView() : _formView(),
      ),
    );
  }

  Widget _formView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20),
    const Icon(Icons.lock_reset, size: 60, color: AppColors.primaryGreen),
    const SizedBox(height: 20),
    const Text('Forgot Password?', style: TextStyle(
      fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    const SizedBox(height: 10),
    const Text('Enter your email and we\'ll send you a reset link.',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 40),
    CustomTextField(
      controller: _email,
      label: 'Email Address',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
    ),
    const SizedBox(height: 32),
    CustomButton(label: 'Send Reset Link', loading: _loading, onPressed: _reset),
  ]);

  Widget _sentView() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Icon(Icons.mark_email_read, size: 80, color: AppColors.accentGreen),
      const SizedBox(height: 20),
      const Text('Check Your Email', style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      Text('We\'ve sent a reset link to\n${_email.text}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
      const SizedBox(height: 40),
      CustomButton(label: 'Back to Login', onPressed: () => context.go('/login')),
    ],
  );
}
