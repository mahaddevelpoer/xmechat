import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatscreen.dart';
import 'widgets/user_tile.dart';
import 'profile_screen.dart';
import 'login.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String? selectedChatId;

  Future<String> getChat(String other) async {
    final me = FirebaseAuth.instance.currentUser!.uid;

    final chats = await FirebaseFirestore.instance
        .collection("chats")
        .where("users", arrayContains: me)
        .get();

    for (var c in chats.docs) {
      List u = c["users"];
      if (u.contains(other)) return c.id;
    }

    final newChat = await FirebaseFirestore.instance.collection("chats").add({
      "users": [me, other],
      "lastMessage": "",
      "timestamp": FieldValue.serverTimestamp(),
    });

    return newChat.id;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return const SizedBox();

    final isDesktop = MediaQuery.of(context).size.width > 600;

    final userList = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("WhatsApp", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search), 
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search tapped")));
            }
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              } else if (value == 'Logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Profile', 'Logout'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").snapshots(),
        builder: (_, snap) {
          if (snap.hasError) return const Center(child: Text("Error loading users"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final users = snap.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i].data() as Map<String, dynamic>;
              final userId = users[i].id;

              if (userId == me) return const SizedBox();

              return UserTile(
                name: u["name"] ?? "Unknown",
                image: u["photoUrl"],
                onTap: () async {
                  final chatId = await getChat(userId);
                  if (isDesktop) {
                    setState(() => selectedChatId = chatId);
                  } else {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chatId: chatId),
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Chat tapped")));
        },
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          SizedBox(
            width: 350,
            child: userList,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.grey),
          Expanded(
            child: selectedChatId == null
                ? Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: const Center(
                      child: Text("WhatsApp for Desktop", style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ),
                  )
                : ChatScreen(chatId: selectedChatId!, key: ValueKey(selectedChatId)),
          ),
        ],
      );
    }

    return userList;
  }
}
