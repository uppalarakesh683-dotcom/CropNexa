import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      // 1. Check whether phone Location/GPS is ON
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      debugPrint('📍 Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('❌ Phone Location/GPS is OFF');
        return null;
      }

      // 2. Check permission
      LocationPermission permission =
          await Geolocator.checkPermission();

      debugPrint('📍 Current permission: $permission');

      // 3. Request permission if necessary
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        debugPrint('📍 Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return null;
        }
      }

      // 4. Permanently denied
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return null;
      }

      // 5. Get actual GPS position
      debugPrint('📍 Getting current GPS position...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint(
        '✅ GPS POSITION: '
        '${position.latitude}, ${position.longitude}',
      );

      debugPrint(
        '🎯 Accuracy: ${position.accuracy} meters',
      );

      return position;
    } catch (e) {
      debugPrint('❌ Location error: $e');
      return null;
    }
  }
}