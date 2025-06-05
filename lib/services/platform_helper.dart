import 'package:flutter/foundation.dart';

class PlatformHelper {
  /// Check if the current platform supports notifications
  static bool get supportsNotifications => !kIsWeb;
  
  /// Check if the current platform supports device orientation control
  static bool get supportsOrientationControl => !kIsWeb;
  
  /// Check if the current platform supports background app refresh
  static bool get supportsBackgroundRefresh => !kIsWeb;
  
  /// Check if the current platform needs location permission handling
  static bool get needsLocationPermissions => !kIsWeb;
  
  /// Get platform-specific error messages for location
  static String getLocationErrorMessage(String error) {
    if (kIsWeb) {
      return "Location access denied by browser. Please click the location icon in your browser's address bar and allow location access.";
    }
    return error;
  }
  
  /// Get platform-specific suggestions for features
  static String getFeatureSuggestion(String feature) {
    if (kIsWeb) {
      switch (feature.toLowerCase()) {
        case 'notifications':
          return "Notifications are not supported on web. Consider bookmarking this page or adding it to your home screen for quick access.";
        case 'background':
          return "Background updates are limited on web. Keep this tab open for real-time updates.";
        default:
          return "This feature has limited functionality on web browsers.";
      }
    }
    return "Feature available on mobile app.";
  }
}
