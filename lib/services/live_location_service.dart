import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract interface class LiveLocationService {
  Future<LatLng> getCurrentLocation();
}

class LiveLocationException implements Exception {
  const LiveLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeolocatorLiveLocationService implements LiveLocationService {
  const GeolocatorLiveLocationService();

  @override
  Future<LatLng> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LiveLocationException('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LiveLocationException('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LiveLocationException(
        'Location permissions are permanently denied',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(position.latitude, position.longitude);
  }
}
