import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../models/models.dart';

enum _SearchState { idle, loading, found, notFound, ownAccount, error }

/// Add group member dialog:
/// - Tabs: By Email | By Phone
/// - Search button
/// - Returns selected [UserModel] via Navigator.pop(context, user)
class AddGroupMemberSheet extends ConsumerStatefulWidget {
  const AddGroupMemberSheet({super.key});

  @override
  ConsumerState<AddGroupMemberSheet> createState() => _AddGroupMemberSheetState();
}

class _AddGroupMemberSheetState extends ConsumerState<AddGroupMemberSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  _SearchState _emailState = _SearchState.idle;
  _SearchState _phoneState = _SearchState.idle;

  UserModel? _emailResult;
  UserModel? _phoneResult;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _searchByEmail() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() {
      _emailState = _SearchState.loading;
      _emailResult = null;
    });

    try {
      final result = await Supabase.instance.client
          .from('users')
          .select('id, name, email, avatar_url, phone_info')
          .ilike('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (result == null) {
        setState(() => _emailState = _SearchState.notFound);
      } else if (result['id'] == _myId) {
        setState(() => _emailState = _SearchState.ownAccount);
      } else {
        setState(() {
          _emailResult = UserModel.fromMap(result);
          _emailState = _SearchState.found;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _emailState = _SearchState.error);
    }
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _phoneState = _SearchState.loading;
      _phoneResult = null;
    });

    try {
      final result = await Supabase.instance.client
          .from('users')
          .select('id, name, email, avatar_url, phone_info')
          .eq('phone_info', phone)
          .maybeSingle();

      if (!mounted) return;

      if (result == null) {
        setState(() => _phoneState = _SearchState.notFound);
      } else if (result['id'] == _myId) {
        setState(() => _phoneState = _SearchState.ownAccount);
      } else {
        setState(() {
          _phoneResult = UserModel.fromMap(result);
          _phoneState = _SearchState.found;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _phoneState = _SearchState.error);
    }
  }

  Widget _resultArea(_SearchState state, UserModel? user) {
    switch (state) {
      case _SearchState.idle:
        return const SizedBox.shrink();
      case _SearchState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
        );
      case _SearchState.notFound:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 52, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('This person is not on XmeChat',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      case _SearchState.ownAccount:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 52, color: AppColors.primaryGreen),
              SizedBox(height: 12),
              Text('This is your own account',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      case _SearchState.error:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 52, color: AppColors.error),
              SizedBox(height: 12),
              Text('Something went wrong, try again',
                  style: TextStyle(fontSize: 15, color: AppColors.error)),
            ],
          ),
        );
      case _SearchState.found:
        if (user == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryGreen.withAlpha(25),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name.trim()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(user.email,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, user),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add to group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _emailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Search by Email Address',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _searchByEmail(),
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.bgSecondary,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed:
                  _emailState == _SearchState.loading ? null : _searchByEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _emailState == _SearchState.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Search'),
            ),
          ]),
          _resultArea(_emailState, _emailResult),
        ],
      ),
    );
  }

  Widget _phoneTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Search by Phone Number',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                onSubmitted: (_) => _searchByPhone(),
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.bgSecondary,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed:
                  _phoneState == _SearchState.loading ? null : _searchByPhone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _phoneState == _SearchState.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Search'),
            ),
          ]),
          _resultArea(_phoneState, _phoneResult),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                const Text('Add member',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textHint, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tab,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textHint,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.email_outlined, size: 18), text: 'By Email'),
                  Tab(icon: Icon(Icons.phone_outlined, size: 18), text: 'By Phone'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: TabBarView(
                controller: _tab,
                children: [_emailTab(), _phoneTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

