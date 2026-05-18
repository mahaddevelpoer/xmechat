import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NotificationService {
  static const String appId = "YOUR_ONESIGNAL_APP_ID"; 
  static const String restApiKey = "YOUR_REST_API_KEY"; 

  static Future<void> init() async {
    // kIsWeb is the safest check for Web to avoid dart:io Platform errors
    if (kIsWeb) return;

    // Use defaultTargetPlatform for cross-platform compatibility
    if (defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(appId);
    OneSignal.Notifications.requestPermission(true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      OneSignal.login(uid);
    }
  }

  static Future<void> sendNotification(String targetUid, String title, String message) async {
    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_external_user_ids': [targetUid],
          'headings': {'en': title},
          'contents': {'en': message},
          'android_channel_id': 'default',
        }),
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }
}
