import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_router.dart';
import 'api_client.dart';

/// Firebase Cloud Messaging: registers the device token (for weekly tips +
/// dispatch alerts) and surfaces foreground messages as local notifications.
/// Best-effort — if Firebase isn't configured it logs and no-ops.
class FCMService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      FirebaseMessaging.onMessage.listen(_showLocalNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _navigateForAction(m.data['action']));

      _initialized = true;
    } catch (e) {
      debugPrint('FCM init skipped (not configured): $e');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      await apiClient.put('/api/auth/fcm-token', data: {'fcmToken': token});
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed (non-fatal): $e');
    }
  }

  static void _handleNotificationTap(NotificationResponse response) {
    _navigateForAction(response.payload);
  }

  static void _navigateForAction(String? action) {
    switch (action) {
      case 'open_first_aid':
        appRouter.go(Routes.firstAid);
        break;
      case 'dispatch_request':
        appRouter.go(Routes.driverHome);
        break;
      default:
        appRouter.go(Routes.home);
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'resqpk_general',
          'General Notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: message.data['action'],
    );
  }
}
