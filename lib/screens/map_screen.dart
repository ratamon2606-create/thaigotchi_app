import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../models/pet_state.dart';
import '../services/ble_service.dart';
import '../services/locations_service.dart';
import '../services/geofencing_service.dart';
import '../services/settings_service.dart';
import '../services/rag_service.dart';
import '../services/tip_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _ble = BLEService();
  final _locations = LocationsService();
  final _geofence = GeofencingService();
  final _settings = SettingsService();
  final _rag = LocalRAGService();
  final _tips = TipService();
  final _voice = VoiceService();
  final _history = ChatHistoryService();
  final _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(13.7472, 100.4917);

  @override
  void initState() {
    super.initState();
    _locations.addListener(_onUpdate);
    _geofence.addListener(_onUpdate);
    _ble.addListener(_onUpdate);
    _geofence.addUnlockListener(_handleUnlock);
    _startGeofencing();
  }

  Future<void> _startGeofencing() async {
    bool ok = await _geofence.init();
    if (ok) {
      _geofence.startTracking(_locations.locations);
    }
  }

  void _handleUnlock(String locationId) async {
    final location = _locations.getById(locationId);
    if (location == null) return;
    
    _locations.unlockLocation(locationId);
    final story = _rag.getLocationStory(locationId, _settings.language);
    final spokenByDevice = _ble.isConnected;
    
    await _history.addMessage(ChatMessage(
      text: story,
      isPet: true,
      source: MessageSource.unlock,
      timestamp: DateTime.now(),
      locationId: locationId,
      spokenByDevice: spokenByDevice,
    ));
    
    if (spokenByDevice) {
      _ble.notifyUnlock(locationId);
      _ble.setPose('talking');
      _ble.playAudio('${locationId}_intro');
    } else {
      _voice.speak(story);
    }
    
    // Start dripping contextual tips into chat (one every 3 min)
    _tips.startTipsForLocation(locationId);
    
    if (mounted) {
      _showUnlockDialog(location, story);
    }
  }

  void _showUnlockDialog(CulturalLocation location, String story) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open,
                color: AppColors.leafGreen, size: 48),
              const SizedBox(height: 12),
              Text(
                _settings.isThai ? location.nameTh : location.nameEn,
                style: const TextStyle(
                  fontFamily: 'ChulabhornLikit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cafeDeepBrown,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(story,
                    style: const TextStyle(
                      fontFamily: 'ChulabhornLikit',
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.cafeDeepBrown,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_settings.isThai ? 'ขอบคุณค่ะ' : 'Thanks!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locations.removeListener(_onUpdate);
    _geofence.removeListener(_onUpdate);
    _ble.removeListener(_onUpdate);
    _geofence.removeUnlockListener(_handleUnlock);
    _tips.stopTips();
    super.dispose();
  }

  /// DEBUG: pretend we're standing at Wat Phra Kaew
  /// DEBUG: cycle through the 3 temples on each tap
  int _debugTempleIndex = 0;
  void _debugTeleport() {
    // 3 temples in order: phra kaew → arun → pho
    const spots = [
      ['Wat Phra Kaew', 13.7515, 100.4929],
      ['Wat Arun', 13.7437, 100.4889],
      ['Wat Pho', 13.7466, 100.4933],
    ];

    final spot = spots[_debugTempleIndex % spots.length];
    final name = spot[0] as String;
    final lat = spot[1] as double;
    final lng = spot[2] as double;

    _geofence.setFakePosition(lat, lng, _locations.locations);
    _mapController.move(LatLng(lat, lng), 16);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🧪 Teleported to $name'),
        duration: const Duration(seconds: 2),
      ),
    );

    _debugTempleIndex++;  // next tap → next temple
  }

  void _onUpdate() {
    if (mounted) setState(() {});
    
    // Update RAG context + tip drip based on current proximity
    final position = _geofence.currentPosition;
    if (position == null) return;
    
    String? nearbyUnlocked;
    for (var loc in _locations.locations) {
      double dist = _geofence.distanceTo(loc);
      // If within 200m, set as RAG context (broader than unlock radius)
      if (dist < 200) {
        _rag.setLocationContext(loc.id);
        if (loc.unlocked) nearbyUnlocked = loc.id;
        break;
      }
    }
    
    // If user is near an unlocked location, keep tips dripping
    // If moved away, stop them
    if (nearbyUnlocked != null && _ble.isConnected) {
      // Already running if was running before; idempotent
      _tips.startTipsForLocation(nearbyUnlocked);
    } else {
      _tips.stopTips();
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = _defaultCenter;
    if (_geofence.currentPosition != null) {
      center = LatLng(
        _geofence.currentPosition!.latitude,
        _geofence.currentPosition!.longitude,
      );
    }

    final locations = _locations.locations;
    
    /// Explorer rank label based on how many places unlocked
    String _explorerLabel() {
      final n = _locations.unlockedCount;
      final th = _settings.isThai;
      if (n >= 3) return th ? 'นักท่องเที่ยวตัวจริง' : 'True Explorer';
      if (n == 2) return th ? 'นักสำรวจวัฒนธรรม' : 'Culture Seeker';
      if (n == 1) return th ? 'นักเดินทางมือใหม่' : 'Wandering Novice';
      return th ? 'นักท่องเที่ยวหน้าใหม่' : 'New Explorer';
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map fills entire screen
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 14,
                minZoom: 11,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.thaigotchi.app',
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile error: $error');
                  },
                ),
                CircleLayer(
                  circles: locations.map((loc) => CircleMarker(
                    point: LatLng(loc.latitude, loc.longitude),
                    radius: loc.unlockRadiusMeters,
                    useRadiusInMeter: true,
                    color: loc.unlocked
                        ? AppColors.leafGreen.withValues(alpha: 0.15)
                        : AppColors.cafeBrickRed.withValues(alpha: 0.1),
                    borderColor: loc.unlocked
                        ? AppColors.leafGreen
                        : AppColors.cafeBrickRed,
                    borderStrokeWidth: 1.5,
                  )).toList(),
                ),
                MarkerLayer(
                  markers: _buildLocationMarkers(locations),
                ),
                if (_geofence.currentPosition != null)
                  MarkerLayer(markers: [_buildUserMarker(center)]),
              ],
            ),
          ),
          
          // Top: small header pill (NOT covering whole screen)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cafeBrickRed,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _settings.t('map_header'),
                        style: const TextStyle(
                          fontFamily: 'ChulabhornLikit',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Right side: my-location button
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _mapController.move(center, 15),
                    icon: const Icon(
                      Icons.my_location,
                      color: AppColors.leafGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // DEBUG: Teleport to temple for testing (remove before release)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 70,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cafeBrickRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: 'Test: teleport to Wat Phra Kaew',
                onPressed: _debugTeleport,
                icon: const Icon(Icons.bug_report, color: AppColors.white),
              ),
            ),
          ),
          
          // Bottom: small floating progress chip (does NOT block taps elsewhere)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: IgnorePointer(
              ignoring: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(_settings.t('map_progress'),
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 12,
                        color: AppColors.cafeWallBrown,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_locations.unlockedCount}/${_locations.totalCount}',
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cafeDeepBrown,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Explorer rank label (fills the middle gap)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _explorerLabel(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'ChulabhornLikit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cafeBrickRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: _locations.totalCount > 0
                            ? _locations.unlockedCount / _locations.totalCount
                            : 0,
                        backgroundColor:
                            AppColors.cafeAccent.withValues(alpha: 0.3),
                        color: AppColors.leafGreen,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildLocationMarkers(List<CulturalLocation> locations) {
    return locations.map((loc) {
      return Marker(
        point: LatLng(loc.latitude, loc.longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showLocationDetails(loc),
          child: Container(
            decoration: BoxDecoration(
              color: loc.unlocked
                  ? AppColors.leafGreen
                  : AppColors.cafeBrickRed,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              loc.unlocked ? Icons.check : Icons.lock,
              color: AppColors.white,
              size: 22,
            ),
          ),
        ),
      );
    }).toList();
  }

  Marker _buildUserMarker(LatLng position) {
    return Marker(
      point: position,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.info,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDetails(CulturalLocation location) {
    final distance = _geofence.distanceTo(location);
    final tips = _tips.getAllTips(location.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Sheet uses up to ~70% of screen, draggable down
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: location.unlocked ? 0.6 : 0.35,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              24, 12, 24,
              24 + MediaQuery.of(ctx).padding.bottom,
            ),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: location.unlocked
                          ? AppColors.leafGreen
                          : AppColors.cafeBrickRed,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      location.unlocked ? Icons.check : Icons.lock,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _settings.isThai ? location.nameTh : location.nameEn,
                          style: const TextStyle(
                            fontFamily: 'ChulabhornLikit',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cafeDeepBrown,
                          ),
                        ),
                        Text(
                          _settings.isThai
                              ? location.teaserTh
                              : location.teaserEn,
                          style: const TextStyle(
                            fontFamily: 'ChulabhornLikit',
                            fontSize: 13,
                            color: AppColors.cafeWallBrown,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Distance chip (always shown)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cafeAccent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk,
                      size: 16, color: AppColors.cafeWallBrown),
                    const SizedBox(width: 8),
                    Text(
                      distance < double.infinity
                          ? _formatDistance(distance)
                          : (_settings.isThai
                              ? 'กำลังหาตำแหน่ง...'
                              : 'Locating...'),
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 13,
                        color: AppColors.cafeDeepBrown,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 12),
              
              // Opening hours status (open now / closed)
              Builder(builder: (_) {
                final (isOpen, label) = _openStatus(location.id);
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isOpen ? AppColors.leafGreen : AppColors.cafeBrickRed)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOpen ? Icons.schedule : Icons.lock_clock,
                          size: 16,
                          color: isOpen ? AppColors.leafGreen : AppColors.cafeBrickRed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'ChulabhornLikit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? AppColors.leafGreen : AppColors.cafeBrickRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              
              // Locked state notice
              
              // Locked state notice
              if (!location.unlocked)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cafeBrickRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                        size: 18, color: AppColors.cafeBrickRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _settings.t('map_locked'),
                          style: const TextStyle(
                            fontFamily: 'ChulabhornLikit',
                            fontSize: 13,
                            color: AppColors.cafeDeepBrown,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Tips list — shown after unlock
              if (location.unlocked && tips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates,
                      size: 18, color: AppColors.leafGreen),
                    const SizedBox(width: 8),
                    Text(
                      _settings.isThai ? 'เกร็ดน่ารู้' : 'Did you know',
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cafeDeepBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tips.map((tip) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cafeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cafeAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                        size: 16, color: AppColors.cafeBrickRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip.text(_settings.language),
                          style: const TextStyle(
                            fontFamily: 'ChulabhornLikit',
                            fontSize: 13,
                            color: AppColors.cafeDeepBrown,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return _settings.isThai
          ? 'อยู่ห่าง ${meters.toInt()} เมตร'
          : '${meters.toInt()}m away';
    }
    final km = meters / 1000;
    return _settings.isThai
        ? 'อยู่ห่าง ${km.toStringAsFixed(1)} กิโลเมตร'
        : '${km.toStringAsFixed(1)}km away';
  }

  /// Opening hours per temple (24h format: [openHour, openMin, closeHour, closeMin])
  static const Map<String, List<int>> _openingHours = {
    'wat_phra_kaew': [8, 30, 16, 30],
    'wat_arun':      [8, 0, 17, 30],
    'wat_pho':       [8, 0, 18, 30],
  };

  /// Returns (isOpen, label) for a location based on current time
  (bool, String) _openStatus(String locationId) {
    final hours = _openingHours[locationId];
    if (hours == null) return (true, '');

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final openMin = hours[0] * 60 + hours[1];
    final closeMin = hours[2] * 60 + hours[3];
    final isOpen = nowMin >= openMin && nowMin < closeMin;

    final th = _settings.isThai;
    final openStr = '${hours[0].toString().padLeft(2, '0')}:${hours[1].toString().padLeft(2, '0')}';
    final closeStr = '${hours[2].toString().padLeft(2, '0')}:${hours[3].toString().padLeft(2, '0')}';

    if (isOpen) {
      return (true, th ? 'เปิดอยู่ • ปิด $closeStr' : 'Open • closes $closeStr');
    } else {
      return (false, th ? 'ปิดแล้ว • เปิด $openStr' : 'Closed • opens $openStr');
    }
  }
}