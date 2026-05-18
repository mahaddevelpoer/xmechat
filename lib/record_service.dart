import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class RecordService {
  final AudioRecorder recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await recorder.hasPermission();
  }

  Future<void> start() async {
    try {
      if (await recorder.hasPermission()) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String fileName = '${const Uuid().v4()}.m4a';
        final String path = '${appDocDir.path}/$fileName';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        await recorder.start(config, path: path);
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<String?> stop() async {
    try {
      return await recorder.stop();
    } catch (e) {
      debugPrint('Error stopping record: $e');
      return null;
    }
  }

  Future<bool> isRecording() async {
    return await recorder.isRecording();
  }

  void dispose() {
    recorder.dispose();
  }
}
