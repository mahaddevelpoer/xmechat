import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';


class CreateStatusScreen extends ConsumerStatefulWidget {
  const CreateStatusScreen({super.key});
  @override
  ConsumerState<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends ConsumerState<CreateStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();
  Color _bgColor = AppColors.primaryGreen;
  bool _loading = false;
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String _videoExt = 'mp4';

  final List<Color> _colors = [
    AppColors.primaryGreen, const Color(0xFF075E54), const Color(0xFF1A237E),
    const Color(0xFFB71C1C), const Color(0xFF1B5E20), const Color(0xFF4A148C),
    const Color(0xFF37474F), Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  Future<void> _pickImage() async {
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
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
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
        setState(() {
          _videoBytes = bytes;
          _videoExt = file.extension ?? 'mp4';
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _post() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(statusServiceProvider);
      if (_tabCtrl.index == 0 && _textCtrl.text.trim().isNotEmpty) {
        await svc.postTextStatus(
          text: _textCtrl.text.trim(),
          bgColor: '#${_bgColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        );
      } else if (_tabCtrl.index == 1 && _imageBytes != null) {
        await svc.postImageStatus(_imageBytes!);
      } else if (_tabCtrl.index == 2 && _videoBytes != null) {
        await svc.postVideoStatus(_videoBytes!, _videoExt);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add content')));
        return;
      }
      await Future.wait([
        ref.refresh(myStatusesProvider.future),
        ref.refresh(statusesProvider.future),
      ]);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _tabCtrl.dispose(); _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Add Status'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(icon: Icon(Icons.text_fields), text: 'Text'),
          Tab(icon: Icon(Icons.image), text: 'Photo'),
          Tab(icon: Icon(Icons.videocam), text: 'Video'),
        ]),
        actions: [
          TextButton(
            onPressed: _loading ? null : _post,
            child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        // Text Status
        Container(
          color: _bgColor,
          child: Column(children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type a status...',
                      hintStyle: TextStyle(color: Colors.white60, fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
            // Color picker
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: _colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _bgColor = c),
                  child: Container(
                    width: 40, height: 40, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: _bgColor == c ? Colors.white : Colors.transparent, width: 3),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
        // Image Status
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            color: AppColors.bgSecondary,
            child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_photo_alternate, size: 80, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text('Tap to select photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ])),
          ),
        ),
        // Video Status
        GestureDetector(
          onTap: _pickVideo,
          child: Container(
            color: AppColors.bgSecondary,
            child: _videoBytes != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 80, color: AppColors.primaryGreen),
                      const SizedBox(height: 16),
                      Text('Video selected (.$_videoExt)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${(_videoBytes!.length / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 16),
                      const Text('Tap to change video', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.video_library, size: 80, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text('Tap to select video', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ])),
          ),
        ),
      ]),
    );
  }
}
