import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/status_service.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final _textCtrl = TextEditingController();
  bool _isText = true;
  bool _loading = false;
  Uint8List? _mediaBytes;
  String? _mediaType;
  late final String _myId;
  late final StatusService _statusService;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _statusService = StatusService(_myId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']),
          XTypeGroup(extensions: ['mp4', 'mov', 'avi']),
        ],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        if (mounted) {
          setState(() {
            _mediaBytes = bytes;
            _mediaType = ['mp4', 'mov', 'avi'].contains(ext) ? 'video' : 'image';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _post() async {
    setState(() => _loading = true);
    try {
      if (_isText) {
        final text = _textCtrl.text.trim();
        if (text.isEmpty) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        await _statusService.postTextStatus(text: text);
      } else if (_mediaBytes != null) {
        if (_mediaType == 'video') {
          await _statusService.postVideoStatus(_mediaBytes!, 'mp4');
        } else {
          await _statusService.postImageStatus(_mediaBytes!);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post status: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Add Status'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _post,
            child: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Share'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Text'),
                  selected: _isText,
                  onSelected: (_) => setState(() { _isText = true; _mediaBytes = null; }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Media'),
                  selected: !_isText,
                  onSelected: (_) => setState(() => _isText = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isText ? _buildTextInput() : _buildMediaInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'What\'s on your mind?',
              border: InputBorder.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaInput() {
    return GestureDetector(
      onTap: _pickMedia,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Center(
          child: _mediaBytes != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mediaType == 'video' ? Icons.videocam : Icons.image,
                      size: 48,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 8),
                    Text('Tap to change', style: AppText.preview),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text('Tap to select image or video', style: AppText.preview),
                  ],
                ),
        ),
      ),
    );
  }
}
