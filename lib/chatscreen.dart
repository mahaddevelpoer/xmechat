import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'record_service.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final RecordService recordService = RecordService();

  bool isRecording = false;
  bool isUploading = false;
  String get uid => auth.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    msgController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    recordService.dispose();
    msgController.dispose();
    super.dispose();
  }

  // 💬 SEND TEXT
  Future<void> sendMessage() async {
    if (msgController.text.trim().isEmpty) return;
    final text = msgController.text.trim();
    msgController.clear();

    await firestore.collection("chats").doc(widget.chatId).collection("messages").add({
      "text": text,
      "type": "text",
      "senderId": uid,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  // 🖼 PICK & SEND IMAGE (Windows Optimized)
  Future<void> sendImage() async {
    Uint8List? bytes;

    if (!kIsWeb && Platform.isWindows) {
      // Fast file picker for Windows
      const XTypeGroup typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'png', 'jpeg']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        bytes = await file.readAsBytes();
      }
    } else {
      // Standard picker for Mobile
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img != null) {
        bytes = await img.readAsBytes();
      }
    }

    if (bytes == null) return;

    setState(() => isUploading = true);
    
    try {
      final name = "${DateTime.now().millisecondsSinceEpoch}";
      await Supabase.instance.client.storage.from('chat-images').uploadBinary(name, bytes);
      final url = Supabase.instance.client.storage.from('chat-images').getPublicUrl(name);

      await firestore.collection("chats").doc(widget.chatId).collection("messages").add({
        "imageUrl": url,
        "type": "image",
        "senderId": uid,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } finally {
      setState(() => isUploading = false);
    }
  }

  // 🎤 VOICE RECORDING
  void startRecording() async {
    if (await recordService.hasPermission()) {
      setState(() => isRecording = true);
      await recordService.start();
    }
  }

  void stopAndSendVoice() async {
    final path = await recordService.stop();
    setState(() => isRecording = false);

    if (path != null) {
      final file = File(path);
      final name = "${DateTime.now().millisecondsSinceEpoch}.m4a";
      await Supabase.instance.client.storage.from('chat-audio').upload(name, file);
      final url = Supabase.instance.client.storage.from('chat-audio').getPublicUrl(name);

      await firestore.collection("chats").doc(widget.chatId).collection("messages").add({
        "audioUrl": url,
        "type": "audio",
        "senderId": uid,
        "timestamp": FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Chat"),
      ),
      body: Column(
        children: [
          if (isUploading) const LinearProgressIndicator(color: Colors.teal),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection("chats").doc(widget.chatId).collection("messages").orderBy("timestamp", descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return MessageBubble(
                      isMe: data["senderId"] == uid,
                      text: data["type"] == "text" ? data["text"] : null,
                      image: data["type"] == "image" ? data["imageUrl"] : null,
                      audio: data["type"] == "audio" ? data["audioUrl"] : null,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                if (!isRecording) ...[
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: isUploading ? null : sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: msgController,
                      onSubmitted: (_) => sendMessage(),
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ] else
                  const Expanded(child: Center(child: Text("Recording...", style: TextStyle(color: Colors.black87)))),

                GestureDetector(
                  onLongPress: startRecording,
                  onLongPressEnd: (_) => stopAndSendVoice(),
                  onTap: () => msgController.text.isNotEmpty ? sendMessage() : null,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Icon(isRecording ? Icons.mic : (msgController.text.isEmpty ? Icons.mic : Icons.send), color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
