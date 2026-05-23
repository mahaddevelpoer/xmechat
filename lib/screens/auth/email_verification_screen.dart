import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';

/// OTP / Email verification screen.
/// Receives the user's email as [email] via go_router extra.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _resendSeconds = 60;

  final List<TextEditingController> _ctrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  late Timer _timer;
  int _secondsLeft = _resendSeconds;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animCtrl.dispose();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste of full OTP
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _ctrls[i].text = digits[i];
      }
      final nextEmpty = _ctrls.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty == -1) {
        _focusNodes[_otpLength - 1].requestFocus();
        _verify();
      } else {
        _focusNodes[nextEmpty].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verify();
      }
    }
    setState(() {});
  }

  void _onKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _ctrls[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < _otpLength) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.email,
      );
      if (!mounted) return;
      // Check if profile exists
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('id', user.id)
            .maybeSingle();
        if (!mounted) return;
        final hasProfile =
            data != null && (data['name'] as String).isNotEmpty;
        context.go(hasProfile ? '/home' : '/profile-setup');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      // Clear boxes on error
      for (final c in _ctrls) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await Supabase.instance.client.auth.resend(
        email: widget.email,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() {
        _secondsLeft = _resendSeconds;
        _error = null;
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to resend. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: AppDeco.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Icon(Icons.mark_email_unread_outlined,
                    size: 40, color: AppColors.accent),
                const SizedBox(height: 14),
                Text('Check your email', style: AppText.heading),
                const SizedBox(height: 6),
                Text(
                  'We sent a 6-digit code to',
                  style: AppText.bodyGrey,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: AppText.body
                      .copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Error
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_error!,
                        style: AppText.body
                            .copyWith(color: AppColors.danger),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                ],

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_otpLength, (i) {
                    return _OtpBox(
                      controller: _ctrls[i],
                      focusNode: _focusNodes[i],
                      onChanged: (v) => _onDigitChanged(i, v),
                      onKeyEvent: (e) => _onKeyEvent(i, e),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: (_loading || _otp.length < _otpLength)
                        ? null
                        : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white),
                          )
                        : const Text('Verify Code'),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Didn\'t receive it? ', style: AppText.bodyGrey),
                    if (_secondsLeft > 0)
                      Text('Resend in ${_secondsLeft}s',
                          style: AppText.hint)
                    else
                      TextButton(
                        onPressed: _resending ? null : _resend,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _resending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.accent),
                              )
                            : const Text('Resend'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('← Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: onKeyEvent,
      child: SizedBox(
        width: 44,
        height: 48,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: AppText.title.copyWith(fontSize: 20),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 2),
            ),
            filled: true,
            fillColor: controller.text.isNotEmpty
                ? AppColors.accentLight
                : AppColors.white,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
