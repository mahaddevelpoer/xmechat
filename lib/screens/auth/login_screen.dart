import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/xmechat_root.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signIn(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);
      // Refresh all providers to clear old session data
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(chatsProvider);
      ref.invalidate(groupsProvider);
      ref.invalidate(statusesProvider);
      ref.invalidate(myStatusesProvider);
      ref.invalidate(callHistoryProvider);
      ref.invalidate(allUsersProvider);
      // Re-attach realtime listeners for new user
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await XmeChatRoot.instance.init();
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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
          child: Form(
            key: _formKey,
            child: Column(children: [
              const SizedBox(height: 30),
              const Text('Welcome Back', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Sign in to continue', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              CustomTextField(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passCtrl,
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primaryGreen)),
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(label: 'Sign In', loading: _loading, onPressed: _login),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Don\'t have an account? ',
                  style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => context.push('/signup'),
                  child: const Text('Create Account',
                    style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
