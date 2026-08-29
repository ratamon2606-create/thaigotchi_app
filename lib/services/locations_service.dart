import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_state.dart';

class LocationsService extends ChangeNotifier {
  static final LocationsService _instance = LocationsService._internal();
  factory LocationsService() => _instance;
  LocationsService._internal();
  
  List<CulturalLocation> _locations = [];
  Set<String> _unlockedIds = {};
  bool _initialized = false;
  
  List<CulturalLocation> get locations {
    return _locations.map((loc) {
      return loc.copyWith(unlocked: _unlockedIds.contains(loc.id));
    }).toList();
  }
  
  int get unlockedCount => _unlockedIds.length;
  int get totalCount => _locations.length;
  Set<String> get unlockedIds => Set.from(_unlockedIds);
  
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Load locations from JSON
      String jsonStr = await rootBundle
          .loadString('assets/data/locations.json');
      Map<String, dynamic> data = jsonDecode(jsonStr);
      
      _locations = (data['locations'] as List).map((json) {
        return CulturalLocation(
          id: json['id'],
          nameTh: json['name_th'],
          nameEn: json['name_en'],
          teaserTh: json['teaser_th'],
          teaserEn: json['teaser_en'],
          latitude: json['latitude'].toDouble(),
          longitude: json['longitude'].toDouble(),
          unlockRadiusMeters: (json['unlock_radius_m'] ?? 50).toDouble(),
        );
      }).toList();
      
      // Load unlocked from storage
      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList('unlocked_locations') ?? [];
      _unlockedIds = unlocked.toSet();
      
      _initialized = true;
      notifyListeners();
      
      debugPrint('✅ Loaded ${_locations.length} locations');
      debugPrint('   Unlocked: ${_unlockedIds.length}');
    } catch (e) {
      debugPrint('❌ LocationsService init error: $e');
    }
  }
  
  Future<void> unlockLocation(String locationId) async {
    if (_unlockedIds.contains(locationId)) return;
    
    _unlockedIds.add(locationId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_locations', _unlockedIds.toList());
    
    notifyListeners();
  }
  
  CulturalLocation? getById(String id) {
    try {
      return _locations.firstWhere((loc) => loc.id == id);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> clearUnlocked() async {
    _unlockedIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unlocked_locations');
    notifyListeners();
  }
}