import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../providers/providers.dart';

class CreateStatusScreen extends ConsumerStatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  ConsumerState<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends ConsumerState<CreateStatusScreen> {
  final _textCtrl = TextEditingController();
  Uint8List? _imageBytes;
  bool _posting = false;
  String _bgColor = '#075E54';

  static const _colors = [
    '#075E54', '#128C7E', '#25D366', '#D32F2F',
    '#1976D2', '#7B1FA2', '#F57C00', '#455A64',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1920);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _postStatus() async {
    setState(() => _posting = true);
    try {
      if (_imageBytes != null) {
        await ref.read(statusServiceProvider).postImageStatus(_imageBytes!);
      } else if (_textCtrl.text.trim().isNotEmpty) {
        await ref.read(statusServiceProvider).postTextStatus(
          text: _textCtrl.text.trim(),
          bgColor: _bgColor,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add text or an image to post a status')),
        );
        if (mounted) setState(() => _posting = false);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status posted')),
        );
        context.canPop() ? context.pop() : context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text('Add Status', style: AppText.title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _posting ? null : _postStatus,
              child: _posting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Share', style: AppText.link),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!, height: 300, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _imageBytes = null),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Remove image'),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Color(int.parse(_bgColor.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 4,
                    textAlign: TextAlign.center,
                    style: AppText.custom(color: Colors.white, fontSize: 20),
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: AppText.custom(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Background Color', style: AppText.name),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((c) {
                  final selected = _bgColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _bgColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: AppColors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            if (_imageBytes == null)
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Add Image'),
              ),
          ],
        ),
      ),
    );
  }
}
