import 'package:geolocator/geolocator.dart';

class ShopperLocation {
  const ShopperLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Thrown when the shopper has not allowed location or the device cannot provide it.
class LocationUnavailable implements Exception {
  const LocationUnavailable();

  static const message =
      'Turn on location for Zubix to see stores near you.';

  @override
  String toString() => message;
}

/// Reads the shopper's position. Injected in tests.
abstract class LocationSource {
  /// Returns the current position, or throws [LocationUnavailable].
  Future<ShopperLocation> current();
}

class GeolocatorLocationSource implements LocationSource {
  @override
  Future<ShopperLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationUnavailable();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationUnavailable();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return ShopperLocation(position.latitude, position.longitude);
    } on LocationUnavailable {
      rethrow;
    } on Exception {
      throw const LocationUnavailable();
    }
  }
}
