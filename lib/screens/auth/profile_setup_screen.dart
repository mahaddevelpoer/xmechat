import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  bool _loading = false;
  Uint8List? _avatarBytes;
  String? _avatarUrl;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_avatarBytes != null) {
        _avatarUrl = await auth.uploadAvatar(_avatarBytes!, 'jpg');
      }
      final uid = auth.currentUserId;
      await auth.upsertProfile(UserModel(
        id: uid,
        email: auth.currentUser?.email ?? '',
        name: _name.text.trim(),
        phoneInfo: _phone.text.trim(),
        bio: _bio.text.trim(),
        avatarUrl: _avatarUrl ?? '',
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      await auth.updateOnlineStatus(true);
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
  void dispose() { _name.dispose(); _phone.dispose(); _bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(children: [
            const SizedBox(height: 20),
            const Text('Set Up Profile', style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('This is how others will see you', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: AppColors.bgSecondary,
                  backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null
                    ? const Icon(Icons.person, size: 55, color: AppColors.textHint)
                    : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _name,
              label: 'Full Name *',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phone,
              label: 'Phone Number (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _bio,
              label: 'Bio (optional)',
              icon: Icons.info_outline,
              maxLines: 2,
            ),
            const SizedBox(height: 36),
            CustomButton(label: 'Continue', loading: _loading, onPressed: _save),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
