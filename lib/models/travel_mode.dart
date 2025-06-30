import 'package:flutter/material.dart';

/// Custom enum for travel modes to use with Google Directions API
enum TravelMode {
  driving,
  walking,
  bicycling,
  transit;

  /// Convert to string for API requests
  String get value => name;
}

/// Information about travel modes for UI display
class TravelModeInfo {
  final String name;
  final IconData icon;
  final TravelMode mode;
  final String description;

  const TravelModeInfo({
    required this.name,
    required this.icon,
    required this.mode,
    required this.description,
  });

  static const List<TravelModeInfo> allModes = [
    TravelModeInfo(
      name: 'Driving',
      icon: Icons.directions_car,
      mode: TravelMode.driving,
      description: 'Route by car or vehicle',
    ),
    TravelModeInfo(
      name: 'Walking',
      icon: Icons.directions_walk,
      mode: TravelMode.walking,
      description: 'Route by foot',
    ),
    TravelModeInfo(
      name: 'Transit',
      icon: Icons.directions_transit,
      mode: TravelMode.transit,
      description: 'Route by public transit',
    ),
    TravelModeInfo(
      name: 'Bicycling',
      icon: Icons.directions_bike,
      mode: TravelMode.bicycling,
      description: 'Route by bicycle',
    ),
  ];
}