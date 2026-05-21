import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'config/router.dart';
import 'providers/providers.dart';
import 'services/xmechat_root.dart';

class XmeChat extends ConsumerStatefulWidget {
  const XmeChat({super.key});

  @override
  ConsumerState<XmeChat> createState() => _XmeChatState();
}

class _XmeChatState extends ConsumerState<XmeChat> {
  bool _markedReady = false;

  @override
  Widget build(BuildContext context) {
    if (!_markedReady) {
      _markedReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        XmeChatRoot.instance.markUiReady();
      });
    }
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'XmeChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
