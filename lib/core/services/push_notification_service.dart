import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:school_erp_staff_app/core/api/api_client.dart';

class PushNotificationService {
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'school_erp_notifications', // Matches backend FcmService channel_id
    'School ERP Notifications',
    description: 'Important updates from the school management system.',
    importance: Importance.max,
    playSound: true,
  );

  /// Foreground data-message hook. A feature (e.g. an open chat thread) can set
  /// this to intercept its own pushes; return true to suppress the banner.
  static bool Function(Map<String, dynamic> data)? onForegroundData;

  /// Returns true if Firebase was initialized, false if skipped.
  static Future<bool> fcmInit(Map<String, dynamic>? firebaseConfig) async {
    if (firebaseConfig == null) {
      debugPrint('ℹ️ [FCM] No Firebase config — push notifications disabled');
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseConfig['apiKey'] ?? '',
            appId: firebaseConfig['appId'] ?? '',
            messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
            projectId: firebaseConfig['projectId'] ?? '',
            storageBucket: firebaseConfig['storageBucket'] ?? '',
          ),
        );
      }

      // Request permission (Android 13+)
      await FirebaseMessaging.instance.requestPermission();

      // Get token
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('ℹ️ [FCM] Obtained token, registering with backend...');
        await _registerTokenWithBackend(token);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenWithBackend);

      // Setup Local Notifications for Android Channels
      if (Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings();
        await _localNotifications.initialize(
          settings: InitializationSettings(android: androidInit, iOS: iosInit),
          onDidReceiveNotificationResponse: (details) {
            // Handle tap on notification
          },
        );
      }

      // Set foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle Foreground Messages explicitly for Android
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final handled = onForegroundData?.call(message.data) ?? false;
        if (handled) return;

        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('⚠️ [FCM] Init failed (non-fatal): $e');
      return false;
    }
  }

  static Future<void> unregister() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient().dio.post('/fcm/token/remove', data: {
          'device_id': token,
        });
        debugPrint('ℹ️ [FCM] Token unregistered with backend');
      }
      await FirebaseMessaging.instance.deleteToken();
      _initialized = false;
    } catch (e) {
      debugPrint('⚠️ [FCM] Unregister failed: $e');
    }
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      String platformStr = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      await ApiClient().dio.post('/fcm/token', data: {
        'token': token,
        'device_type': platformStr,
        'device_id': token, // Surrogate ID for now
      });
      debugPrint('✅ [FCM] Token successfully registered with backend');
    } catch (e) {
      debugPrint('⚠️ [FCM] Backend token registration failed: $e');
    }
  }
}
