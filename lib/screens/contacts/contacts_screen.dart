import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text('Contacts', style: AppText.title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: AppText.hint,
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.white,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: usersAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorState(error: e),
              data: (users) {
                final filtered = _search.isEmpty
                    ? users
                    : users.where((u) =>
                        u.name.toLowerCase().contains(_search.toLowerCase()) ||
                        u.email.toLowerCase().contains(_search.toLowerCase()) ||
                        u.phoneInfo.toLowerCase().contains(_search.toLowerCase())).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.contacts_outlined,
                    title: _search.isEmpty ? 'No contacts found' : 'No results for "$_search"',
                    subtitle: _search.isEmpty ? 'Search for users by name, email, or phone' : null,
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final user = filtered[i];
                    return InkWell(
                      onTap: () => context.push('/contact/${user.id}', extra: {'user': user}),
                      child: Container(
                        height: AppSizes.chatItemHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            UserAvatar(imageUrl: user.avatarUrl, name: user.name, size: AppSizes.avatarMd),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: AppText.name, overflow: TextOverflow.ellipsis),
                                  Text(user.email, style: AppText.bodyGrey, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              onPressed: () async {
                                final chatId = await ref.read(chatServiceProvider).getOrCreateChat(user.id);
                                if (context.mounted) {
                                  context.push('/chat/$chatId', extra: {'user': user});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
