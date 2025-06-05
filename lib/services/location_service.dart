import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kIsWeb) {
          // On web, this might return false even if location is available
          // We'll try to get permission anyway
          return true;
        }
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      print('Location permission check error: $e');
      return false;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission not granted');
      }

      // For web, use a longer timeout and lower accuracy initially
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: kIsWeb ? const Duration(seconds: 30) : const Duration(seconds: 15),
      );
    } catch (e) {
      print('Get current position error: $e');
      
      // If high accuracy fails on web, try with lower accuracy
      if (kIsWeb) {
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 45),
          );
        } catch (e2) {
          print('Fallback position error: $e2');
          return null;
        }
      }
      return null;
    }
  }

  static String getLocationErrorMessage(dynamic error) {
    if (kIsWeb) {
      if (error.toString().contains('denied')) {
        return 'Location access denied. Please allow location access in your browser settings and ensure you\'re using HTTPS.';
      } else if (error.toString().contains('timeout')) {
        return 'Location request timed out. Please try again or check your internet connection.';
      } else if (error.toString().contains('unavailable')) {
        return 'Location is currently unavailable. Please ensure location services are enabled in your browser.';
      }
    }
    return 'Failed to get current location. Please try again.';
  }
}
