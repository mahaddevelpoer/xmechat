import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Uint8List? _avatarBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _nameCtrl.text = user.name;
      _bioCtrl.text = user.bio;
      _phoneCtrl.text = user.phoneInfo;
    }
  }

  Future<void> _pickAvatar() async {
    // This example uses image_picker; ensure dependency is added.
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      setState(() async => _avatarBytes = await img.readAsBytes());
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).updateProfile(
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        phoneInfo: _phoneCtrl.text.trim(),
        avatarBytes: _avatarBytes,
      );
      // Refresh user provider
      ref.refresh(currentUserProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.bgSecondary,
                  backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : (user?.avatarUrl != null ? NetworkImage(user!.avatarUrl) : null) as ImageProvider?,
                  child: _avatarBytes == null && (user?.avatarUrl == null)
                      ? const Icon(Icons.camera_alt, size: 36, color: AppColors.textHint)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _nameCtrl,
                label: 'Name',
                icon: Icons.person_outline,
                validator: (v) => v!.isNotEmpty ? null : 'Name required',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _bioCtrl,
                label: 'Bio',
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneCtrl,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),
              CustomButton(label: _saving ? 'Saving...' : 'Save Changes', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
