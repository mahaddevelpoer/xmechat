import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/desktop.dart';
import 'dart:io' show Platform;

import 'app.dart';
import 'core/constants/supabase_constants.dart';

import 'services/xmechat_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Initialize Firebase for FCM push notifications
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may fail on desktop - that's OK
  }

  // Init Background Service
  await XmeChatRoot.instance.init();

  runApp(
    const ProviderScope(
      child: XmeChat(),
    ),
  );

  // Desktop window config
  if (!kIsWeb && Platform.isWindows) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(900, 650);
      appWindow.size = const Size(1200, 800);
      appWindow.alignment = Alignment.center;
      appWindow.title = "XmeChat";
      appWindow.show();
    });
  }
}
