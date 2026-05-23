import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/auth_service.dart';
import '../../models/models.dart';


class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _authService = AuthService();

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  Uint8List? _avatarBytes;
  String _avatarExt = 'jpg';
  bool _isPrivate = false;
  bool _loading = false;
  String? _error;

  bool get _canContinue =>
      _avatarBytes != null && _nameCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _avatarBytes = file.bytes;
      _avatarExt = file.extension ?? 'jpg';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_avatarBytes == null) {
      setState(() => _error = 'Please choose a profile photo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _authService.currentUserId;

      // Upload avatar
      final avatarUrl =
          await _authService.uploadAvatar(_avatarBytes!, _avatarExt);

      // Upsert profile
      await _authService.upsertProfile(UserModel(
        id: userId,
        email: Supabase.instance.client.auth.currentUser?.email ?? '',
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        phoneInfo: _phoneCtrl.text.trim(),
        avatarUrl: avatarUrl,
        isPrivate: _isPrivate,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = 'Failed to save profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(36),
              decoration: AppDeco.card,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Step header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Step 1 of 1',
                              style: AppText.caption
                                  .copyWith(color: AppColors.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Complete Your Profile', style: AppText.heading),
                    const SizedBox(height: 4),
                    Text('This is how others will see you.',
                        style: AppText.bodyGrey),
                    const SizedBox(height: 28),

                    // Avatar picker
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickPhoto,
                            child: Stack(
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _avatarBytes != null
                                            ? AppColors.accent
                                            : AppColors.border,
                                        width: 2),
                                    color: AppColors.bg,
                                  ),
                                  child: ClipOval(
                                    child: _avatarBytes != null
                                        ? Image.memory(
                                            _avatarBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.person_outline,
                                            size: 44,
                                            color: AppColors.textHint,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.white,
                                          width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.upload_outlined, size: 16),
                            label: Text(_avatarBytes == null
                                ? 'Choose Photo *'
                                : 'Change Photo'),
                          ),
                          if (_avatarBytes == null)
                            Text(
                              'Profile photo is required',
                              style: AppText.caption
                                  .copyWith(color: AppColors.danger),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                                .copyWith(color: AppColors.danger)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full Name
                    _FieldLabel('Full Name', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon:
                            Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Bio
                    _FieldLabel('Bio', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bioCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppText.body,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'A short description about you',
                        prefixIcon: Icon(Icons.info_outline, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Bio is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone (optional)
                    _FieldLabel('Phone', required: false),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: '+92 300 0000000 (optional)',
                        prefixIcon: Icon(Icons.phone_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Privacy toggle
                    InkWell(
                      onTap: () =>
                          setState(() => _isPrivate = !_isPrivate),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _isPrivate,
                                onChanged: (v) =>
                                    setState(() => _isPrivate = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Private account',
                                      style: AppText.body),
                                  Text(
                                    'Only people you choose can find you',
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed:
                            (_canContinue && !_loading) ? _submit : null,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                    if (!_canContinue) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Add a photo and your name to continue',
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppText.bodyGrey),
        if (required)
          Text(' *',
              style: AppText.bodyGrey.copyWith(color: AppColors.danger)),
      ],
    );
  }
}
