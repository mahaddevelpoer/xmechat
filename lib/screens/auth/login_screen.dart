import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMsg;
  final _auth = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await _auth.signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timed out'),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e is AuthException ? e.message : e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Enter your email first');
      return;
    }
    try {
      await _auth.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset link sent to your email.')),
        );
      }
    } catch (e) {
      final msg = e is AuthException ? e.message : 'Failed to send reset link';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text('Welcome to XmeChat', style: AppText.heading),
                const SizedBox(height: 4),
                Text('Sign in to continue', style: AppText.preview),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMsg!, style: AppText.message.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 40,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: AppText.timestamp)),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 40,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, _fadeRoute(const SignupScreen())),
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _forgotPassword, child: const Text('Forgot Password?')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}
