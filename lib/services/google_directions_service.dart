import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart' hide TravelMode;
import 'package:complaints_app/models/travel_mode.dart';

class GoogleDirectionsService {
  static final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  
  Future<List<DirectionsRoute>> getRoutes({
    required LatLng origin,
    required LatLng destination,
    TravelMode travelMode = TravelMode.driving,
    List<LatLng>? waypoints,
    bool alternatives = true,
  }) async {
    try {
      final waypointsParam = waypoints != null && waypoints.isNotEmpty
          ? '&waypoints=${waypoints.map((w) => '${w.latitude},${w.longitude}').join('|')}'
          : '';
          
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=${travelMode.value}'
        '&alternatives=$alternatives'
        '$waypointsParam'
        '&key=$apiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final List<DirectionsRoute> routes = [];
          
          // Parse each route
          for (final routeData in data['routes']) {
            final legs = routeData['legs'] as List;
            final points = routeData['overview_polyline']['points'] as String;
            
            // Create a route object
            final route = DirectionsRoute(
              legs: legs.map((leg) => DirectionsLeg.fromJson(leg)).toList(),
              overviewPolyline: EncodedPolyline(points: points),
            );
            
            routes.add(route);
          }
          
          return routes;
        }
      }
      
      return [];
    } catch (e) {
      print("Error getting directions: $e");
      return [];
    }
  }
  
  List<LatLng> decodePolyline(String encoded) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encoded);
    return decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }
}

// Custom classes to replace the google_maps_webservice ones
class DirectionsRoute {
  final List<DirectionsLeg> legs;
  final EncodedPolyline overviewPolyline;
  
  DirectionsRoute({
    required this.legs,
    required this.overviewPolyline,
  });
}

class DirectionsLeg {
  final Distance? distance;
  final DirectionsDuration? duration;
  
  DirectionsLeg({
    this.distance,
    this.duration,
  });
  
  factory DirectionsLeg.fromJson(Map<String, dynamic> json) {
    return DirectionsLeg(
      distance: json['distance'] != null ? Distance.fromJson(json['distance']) : null,
      duration: json['duration'] != null ? DirectionsDuration.fromJson(json['duration']) : null,
    );
  }
}

class Distance {
  final String text;
  final int value;
  
  Distance({required this.text, required this.value});
  
  factory Distance.fromJson(Map<String, dynamic> json) {
    return Distance(
      text: json['text'],
      value: json['value'],
    );
  }
}

class DirectionsDuration {
  final String text;
  final int value;
  
  DirectionsDuration({required this.text, required this.value});
  
  factory DirectionsDuration.fromJson(Map<String, dynamic> json) {
    return DirectionsDuration(
      text: json['text'],
      value: json['value'],
    );
  }
}

class EncodedPolyline {
  final String? points;
  
  EncodedPolyline({this.points});
}