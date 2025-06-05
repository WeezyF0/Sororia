import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;

class WebGeocoding {
  // Using OpenStreetMap Nominatim API as a fallback for web
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  static Future<List<LatLng>> locationFromAddress(String address) async {
    if (kIsWeb) {
      return await _webLocationFromAddress(address);
    } else {
      // Use the regular geocoding package for mobile
      try {
        List<geo.Location> locations = await geo.locationFromAddress(address);
        return locations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();
      } catch (e) {
        print('Mobile geocoding error: $e');
        return [];
      }
    }
  }
  
  static Future<List<LatLng>> _webLocationFromAddress(String address) async {
    try {
      // Clean the address
      String cleanAddress = address.trim();
      if (cleanAddress.isEmpty) return [];
      
      // URL encode the address
      String encodedAddress = Uri.encodeComponent(cleanAddress);
      
      // Make request to Nominatim
      String url = '$_nominatimBaseUrl/search?q=$encodedAddress&format=json&limit=5&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Sororia App (Web Version)',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        List<dynamic> results = json.decode(response.body);
        
        List<LatLng> locations = [];
        for (var result in results) {
          double? lat = double.tryParse(result['lat']?.toString() ?? '');
          double? lon = double.tryParse(result['lon']?.toString() ?? '');
          
          if (lat != null && lon != null) {
            locations.add(LatLng(lat, lon));
          }
        }
        
        return locations;
      } else {
        print('Nominatim API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Web geocoding error: $e');
      // Try mobile geocoding as final fallback
      try {
        List<geo.Location> locations = await geo.locationFromAddress(address);
        return locations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();
      } catch (e2) {
        print('Mobile geocoding fallback error: $e2');
        return [];
      }
    }
  }
  
  static Future<String?> placemarkFromCoordinates(double latitude, double longitude) async {
    if (kIsWeb) {
      return await _webPlacemarkFromCoordinates(latitude, longitude);
    } else {
      // Use the regular geocoding package for mobile
      try {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
        return placemarks.isNotEmpty ? placemarks.first.locality ?? "Unknown Location" : "Unknown Location";
      } catch (e) {
        print('Mobile reverse geocoding error: $e');
        return "Unknown Location";
      }
    }
  }
  
  static Future<String?> _webPlacemarkFromCoordinates(double latitude, double longitude) async {
    try {
      String url = '$_nominatimBaseUrl/reverse?lat=$latitude&lon=$longitude&format=json&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Sororia App (Web Version)',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> result = json.decode(response.body);
        
        // Try to get a meaningful location name
        Map<String, dynamic>? address = result['address'];
        if (address != null) {
          return address['city'] ?? 
                 address['town'] ?? 
                 address['village'] ?? 
                 address['municipality'] ?? 
                 address['county'] ?? 
                 address['state'] ?? 
                 "Unknown Location";
        }
        
        return result['display_name']?.toString().split(',').first ?? "Unknown Location";
      } else {
        print('Nominatim reverse API error: ${response.statusCode}');
        return "Unknown Location";
      }
    } catch (e) {
      print('Web reverse geocoding error: $e');
      // Try mobile geocoding as final fallback
      try {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
        return placemarks.isNotEmpty ? placemarks.first.locality ?? "Unknown Location" : "Unknown Location";
      } catch (e2) {
        print('Mobile reverse geocoding fallback error: $e2');
        return "Unknown Location";
      }
    }
  }
}
