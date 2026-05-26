import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/constants/supabase_constants.dart';
import 'services/xmechat_root.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  await windowManager.ensureInitialized();

  await XmeChatRoot.instance.init();

  runApp(
    const ProviderScope(
      child: XmeChat(),
    ),
  );

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(1100, 720),
      minimumSize: const Size(800, 600),
      center: true,
      title: 'XmeChat',
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
