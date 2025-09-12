import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Get current FCM token
  static Future<String?> getToken() async {
    try {
      String? token = await _messaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Print token to console (for debugging)
  static Future<void> printToken() async {
    try {
      final token = await getToken();
      print('FCM Token: $token');
    } catch (e) {
      print('Error printing FCM token: $e');
    }
  }

  // Listen for token changes
  static void setupTokenListener({Function(String)? onTokenRefresh}) {
    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');

      // Callback for custom handling (e.g., send to server)
      if (onTokenRefresh != null) {
        onTokenRefresh(newToken);
      }
    });
  }

  // Request notification permissions
  static Future<NotificationSettings> requestPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      print('Notification permissions: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      print('Error requesting notification permissions: $e');
      rethrow;
    }
  }

  // Check current permission status
  static Future<NotificationSettings> getNotificationSettings() async {
    try {
      NotificationSettings settings = await _messaging.getNotificationSettings();
      print('Current notification settings: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      print('Error getting notification settings: $e');
      rethrow;
    }
  }

  // Delete token (useful for logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      print('FCM token deleted');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }

  // Subscribe to topic (for broadcast notifications)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic $topic: $e');
    }
  }
}