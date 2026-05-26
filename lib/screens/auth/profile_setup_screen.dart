import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;
  const ProfileSetupScreen({super.key, required this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isPrivate = false;
  bool _loading = false;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  final _auth = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']),
        ],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last;
        if (mounted) {
          setState(() {
            _avatarBytes = bytes;
            _avatarExt = ext;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _complete() async {
    if (_step < 2) { setState(() => _step++); return; }
    setState(() => _loading = true);
    try {
      String avatarUrl = '';
      if (_avatarBytes != null && _avatarExt != null) {
        avatarUrl = await _auth.uploadAvatar(_avatarBytes!, _avatarExt!);
      }
      await _auth.upsertProfile(UserModel(
        id: _auth.currentUserId,
        email: widget.email,
        name: _nameCtrl.text.trim().isEmpty ? 'User' : _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        phoneInfo: _phoneCtrl.text.trim(),
        avatarUrl: avatarUrl,
        lastSeen: DateTime.now(),
        isPrivate: _isPrivate,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setup failed: $e')));
    }
    if (mounted) setState(() => _loading = false);
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
                _buildStepper(),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _step == 0 ? _buildAvatarStep() : _step == 1 ? _buildInfoStep() : _buildPrivacyStep(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i <= _step ? AppColors.accent : AppColors.border,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildAvatarStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        Text('Add a Profile Picture', style: AppText.heading),
        const SizedBox(height: 8),
        Text('This will be visible to your contacts', style: AppText.preview),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 56,
            backgroundColor: AppColors.accentLight,
            backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
            child: _avatarBytes == null
                ? Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.accent)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: _pickImage, child: const Text('Choose Photo')),
            TextButton(
              onPressed: _avatarBytes == null ? null : () => setState(() { _avatarBytes = null; _avatarExt = null; }),
              child: const Text('Remove'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 40,
          child: ElevatedButton(onPressed: _complete, child: const Text('Next')),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _complete,
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _buildInfoStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        Text('Tell us about yourself', style: AppText.heading),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Display Name *',
            prefixIcon: const Icon(Icons.person_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioCtrl,
          decoration: InputDecoration(
            labelText: 'Bio (optional)',
            prefixIcon: const Icon(Icons.info_outlined),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: InputDecoration(
            labelText: 'Phone Number (optional)',
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 40,
          child: ElevatedButton(onPressed: _complete, child: const Text('Next')),
        ),
      ],
    );
  }

  Widget _buildPrivacyStep() {
    return Column(
      key: const ValueKey(2),
      children: [
        Text('Privacy Settings', style: AppText.heading),
        const SizedBox(height: 8),
        Text('Control who can see your information', style: AppText.preview),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Private Account', style: AppText.name),
                    Text('Only approved contacts can message you', style: AppText.timestamp),
                  ],
                ),
              ),
              Switch(
                value: _isPrivate,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
                activeThumbColor: AppColors.accent,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 40,
          child: ElevatedButton(
            onPressed: _loading ? null : _complete,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Complete Setup'),
          ),
        ),
      ],
    );
  }
}
