import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/pet_state.dart';

/// Geofencing service
/// 
/// Tracks user's phone GPS location and detects when they enter
/// the unlock radius of cultural locations
class GeofencingService extends ChangeNotifier {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();
  
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  
  /// Set of location IDs that have been unlocked
  Set<String> _unlockedLocations = {};
  
  /// Callbacks for unlock events
  final List<void Function(String locationId)> _unlockListeners = [];
  
  Position? get currentPosition => _currentPosition;
  Set<String> get unlockedLocations => Set.from(_unlockedLocations);
  
  /// Initialize and request location permission
  Future<bool> init() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return false;
      }
      
      // Check if location services enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services disabled');
        return false;
      }
      
      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('✅ Geofencing initialized');
      debugPrint('   Position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      
      return true;
    } catch (e) {
      debugPrint('❌ Geofencing init error: $e');
      return false;
    }
  }
  
  /// Start tracking location
  void startTracking(List<CulturalLocation> locations) {
    _positionStream?.cancel();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,  // Update every 10 meters
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _checkProximity(position, locations);
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ Position stream error: $error');
      },
    );
    
    debugPrint('✅ Location tracking started');
  }
  
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
  
  /// Check if user is within radius of any location
  void _checkProximity(Position position, List<CulturalLocation> locations) {
    for (var location in locations) {
      // Skip if already unlocked
      if (_unlockedLocations.contains(location.id)) continue;
      
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );
      
      if (distance <= location.unlockRadiusMeters) {
        _unlockLocation(location.id);
      }
    }
  }
  
  /// Mark location as unlocked
  void _unlockLocation(String locationId) {
    if (_unlockedLocations.contains(locationId)) return;
    
    _unlockedLocations.add(locationId);
    debugPrint('🔓 Unlocked location: $locationId');
    
    // Notify listeners
    for (var listener in _unlockListeners) {
      listener(locationId);
    }
    
    notifyListeners();
  }
  
  /// Manually unlock (for testing/debug)
  void manualUnlock(String locationId) {
    _unlockLocation(locationId);
  }
  
  /// DEBUG: Set a fake position to simulate being at a location.
  /// Used for testing geofence + tips without physically traveling.
  void setFakePosition(double lat, double lng, List<CulturalLocation> locations) {
    _currentPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    debugPrint('🧪 FAKE position set: $lat, $lng');
    _checkProximity(_currentPosition!, locations);
    notifyListeners();
  }
  
  /// Get distance to a location in meters
  double distanceTo(CulturalLocation location) {
    if (_currentPosition == null) return double.infinity;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      location.latitude,
      location.longitude,
    );
  }
  
  /// Add unlock listener
  void addUnlockListener(void Function(String locationId) listener) {
    _unlockListeners.add(listener);
  }
  
  void removeUnlockListener(void Function(String locationId) listener) {
    _unlockListeners.remove(listener);
  }
  
  /// Restore unlocked locations from storage
  void restoreUnlocked(Set<String> unlocked) {
    _unlockedLocations = unlocked;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
