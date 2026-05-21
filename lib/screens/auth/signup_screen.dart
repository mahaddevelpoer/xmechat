import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false, _obscure = true;

  Future<void> _signup() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signUp(
        email: _email.text.trim(), password: _pass.text);
        
      if (!mounted) return;
      context.go('/profile-setup');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _pass.dispose(); _confirm.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: BackButton(color: AppColors.textPrimary)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(key: _form, child: Column(children: [
            const SizedBox(height: 20),
            const Text('Create Account', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Join XmeChat today', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            CustomTextField(
              controller: _email,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.contains('@') ? null : 'Enter valid email',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _pass,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: _obscure,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textHint),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirm,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              obscureText: _obscure,
              validator: (v) => v == _pass.text ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 32),
            CustomButton(label: 'Create Account', loading: _loading, onPressed: _signup),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account? ',
                style: TextStyle(color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text('Sign In',
                  style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 40),
          ])),
        ),
      ),
    );
  }
}
