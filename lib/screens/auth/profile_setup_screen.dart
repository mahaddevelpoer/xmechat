import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;
  const ProfileSetupScreen({super.key, required this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController(text: 'Hey there! I am using XmeChat');
  final _phoneCtrl = TextEditingController();
  XFile? _selectedImage;
  bool _loading = false;
  bool _isPrivate = false;
  String? _errorMsg;

  bool get _canContinue => _nameCtrl.text.trim().length >= 2 && _selectedImage != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_canContinue) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final bytes = await _selectedImage!.readAsBytes();
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      await supabase.from('users').upsert({
        'id': userId,
        'email': widget.email,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'phone_info': _phoneCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'is_private': _isPrivate,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
      setState(() { _errorMsg = 'Failed to save profile: $e'; _loading = false; });
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
            width: 480,
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
                Row(
                  children: [
                    _stepDot(true),
                    const SizedBox(width: 6),
                    _stepDot(true),
                    const SizedBox(width: 6),
                    _stepDot(false),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Set up your profile', style: AppText.heading),
                const SizedBox(height: 4),
                Text('This info will be visible to people you chat with', style: AppText.preview),
                const SizedBox(height: 24),
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.solid),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.accentLight,
                          backgroundImage: _selectedImage != null ? FileImage(File(_selectedImage!.path)) : null,
                          child: _selectedImage == null
                              ? const Icon(Icons.camera_alt, color: AppColors.accent, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Profile Photo', style: AppText.name),
                              const SizedBox(height: 2),
                              Text('Required — choose from gallery', style: AppText.timestamp),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    hintText: 'Your display name (min 2 chars)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Hey there! I am using XmeChat',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (optional)',
                    hintText: '+92 300 0000000',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _isPrivate = !_isPrivate),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isPrivate,
                          onChanged: (v) => setState(() => _isPrivate = v ?? false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only people I choose can find me.\nWhen checked, you will not appear in search results.',
                            style: AppText.preview.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMsg!, style: AppText.message.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: (_canContinue && !_loading) ? _saveProfile : null,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Continue to XmeChat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDot(bool active) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
