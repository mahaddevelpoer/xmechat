import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
  final _bio = TextEditingController(text: 'Friends Forever');
  bool _loading = false;
  bool _privacyChecked = false;
  bool _hasInteracted = false;
  Uint8List? _avatarBytes;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _name.addListener(_updateState);
    _phone.addListener(_updateState);
    _bio.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes != null) {
        setState(() => _avatarBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _hasInteracted = true);
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 2 characters')));
      return;
    }
    if (_phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')));
      return;
    }
    if (_avatarBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a profile picture')));
      return;
    }
    if (_bio.text.trim().isEmpty) {
      _bio.text = 'Friends Forever';
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
        isPrivate: _privacyChecked,
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
  void dispose() { 
    _name.removeListener(_updateState);
    _phone.removeListener(_updateState);
    _bio.removeListener(_updateState);
    _name.dispose(); 
    _phone.dispose(); 
    _bio.dispose(); 
    super.dispose(); 
  }

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
            const SizedBox(height: 8),
            if (_hasInteracted && _name.text.trim().length < 2)
              const Text('Name must be at least 2 characters', style: TextStyle(color: AppColors.error, fontSize: 12)),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _phone,
              label: 'Phone Number *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _bio,
              label: 'Bio *',
              icon: Icons.info_outline,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            if (_hasInteracted && _bio.text.trim().length < 5)
              const Text('Bio must be at least 5 characters', style: TextStyle(color: AppColors.error, fontSize: 12)),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _privacyChecked,
              onChanged: (val) => setState(() => _privacyChecked = val ?? false),
              title: const Text('Only people I choose can find me'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Continue',
              loading: _loading,
              onPressed: (_name.text.trim().length >= 2 && _phone.text.trim().isNotEmpty && _avatarBytes != null && _bio.text.trim().length >= 5) ? _save : null,
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
