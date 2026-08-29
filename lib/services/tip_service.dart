import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service that delivers location-based trivia/tips into chat
/// after the user has unlocked a location.
///
/// First tip fires ~15s after arrival, then one every [intervalMinutes]
/// minutes (default 5). Each tip is shown once per session.
class TipService extends ChangeNotifier {
  static final TipService _instance = TipService._internal();
  factory TipService() => _instance;
  TipService._internal();

  // Tips already shown this session (don't repeat)
  final Set<String> _shownTips = {};

  // Currently scheduled timer
  Timer? _scheduledTip;

  // Which location is currently dripping tips (guards against restart)
  String? _activeLocation;

  // Stream of tip messages to inject into chat
  final _tipController = StreamController<TipMessage>.broadcast();
  Stream<TipMessage> get tipStream => _tipController.stream;

  /// Tips library — per location
  /// Each tip is a "did you know" style nudge
  static const Map<String, List<TipDefinition>> _tipsLibrary = {
    'wat_phra_kaew': [
      TipDefinition(
        topicId: 'wpk_giants',
        textTh: 'อย่าลืมไปดูยักษ์ทวารบาลที่เฝ้าประตูนะครับ มี 12 ตน 6 คู่ ตัวเอ้คือทศกัณฐ์เขียวกับสหัสเดชะขาว',
        textEn: 'Don\'t miss the 12 giant guardians at the gates! The famous pair: green Thotsakan and white Sahatsadecha.',
        lat: 13.751495935386698,
        lng: 100.49214354165258,
      ),
      TipDefinition(
        topicId: 'wpk_murals',
        textTh: 'แวะดูจิตรกรรมรามเกียรติ์รอบระเบียงด้วยนะครับ มี 178 ห้อง เดินทวนเข็มนาฬิกาจะอ่านเรียงตามลำดับ',
        textEn: 'Walk the cloister to see the Ramakien murals—178 panels! Counter-clockwise to follow the story.',
        lat: 13.751928,
        lng: 100.492984,
      ),
      TipDefinition(
        topicId: 'wpk_hidden_art',
        textTh: 'ลองหาภาพกากที่ช่างแอบวาดในจิตรกรรมดูครับ มีฝรั่งใส่หมวก คนทำกับข้าว สนุกเหมือนหา easter egg',
        textEn: 'Look for hidden "phap kak" scenes painters secretly added—foreigners, cooks, even toilet-goers! Easter egg hunt!',
        lat: 13.751928,
        lng: 100.492984,
      ),
      TipDefinition(
        topicId: 'wpk_chedi',
        textTh: 'พระศรีรัตนเจดีย์ทองที่เห็นเด่นๆ ประดับด้วยกระเบื้องโมเสกจากอิตาลีนะครับ',
        textEn: 'The golden chedi you can see clearly? Decorated with mosaic tiles from Italy!',
        lat: 13.751630,
        lng: 100.492331,
      ),
      TipDefinition(
        topicId: 'wpk_angkor',
        textTh: 'ในวัดมีนครวัดจำลองด้วยนะครับ รัชกาลที่ 4 โปรดให้สร้างเพื่อให้คนไทยเห็นความยิ่งใหญ่ของเขมร',
        textEn: 'There\'s a miniature Angkor Wat replica too! Built by Rama IV to show Cambodia\'s greatness.',
        lat: 13.751801,
        lng: 100.492494,
      ),
      TipDefinition(
        topicId: 'wpk_holy_water',
        textTh: 'ก่อนเข้าโบสถ์มีจุดรับน้ำมนต์ดอกบัวให้เคาะศีรษะเพื่อความเป็นมงคลครับ',
        textEn: 'Before entering the main hall, there\'s a holy water station with lotus stems for blessings.',
        lat: 13.751160811283691,
        lng: 100.49264741668179,
      ),
    ],

    'wat_pho': [
      TipDefinition(
        topicId: 'wp_108_bowls',
        textTh: 'ด้านหลังพระนอนมีบาตร 108 ใบครับ ลองซื้อเหรียญหยอดทีละใบฟังเสียงกังวานเพื่อทำสมาธิ',
        textEn: 'Behind the Reclining Buddha: 108 alms bowls! Drop coins one by one—soothing for meditation.',
        lat: 13.746554211500127,
        lng: 100.49166290661489,
      ),
      TipDefinition(
        topicId: 'wp_real_giants',
        textTh: 'ยักษ์วัดโพธิ์ตัวจริงไม่ใช่ลั่นถันใหญ่ๆ หน้าวัดนะครับ ตัวจริงคือยักษ์ 4 ตนเล็กซ่อนอยู่ในซุ้มประตูพระมณฑป',
        textEn: 'The "real" Wat Pho giants aren\'t the big Chinese statues—they\'re 4 small ones hidden in the Phra Mondop arches!',
        lat: 13.745913470006437,
        lng: 100.49187049437171,
      ),
      TipDefinition(
        topicId: 'wp_pagodas',
        textTh: 'มหาเจดีย์ 4 องค์มีสีต่างกันตามรัชกาลครับ เขียว ขาว เหลือง น้ำเงิน — รัชกาลที่ 1 ถึง 4',
        textEn: 'The 4 royal pagodas have different colors: green, white, yellow, blue—for Kings Rama I-IV.',
        lat: 13.746464089616756,
        lng: 100.49271387841858,
      ),
      TipDefinition(
        topicId: 'wp_massage',
        textTh: 'อย่าพลาดนวดแผนไทยของแท้ครับ จองคิวที่ศาลาการเปรียญ 480 บาทต่อชั่วโมง คุ้มมาก',
        textEn: 'Don\'t miss authentic Thai massage! Book at the school inside—480 baht/hour, totally worth it.',
        lat: 13.746464089616756,
        lng: 100.49271387841858,
      ),
      TipDefinition(
        topicId: 'wp_tha_tien',
        textTh: 'รู้มั้ยครับ ชื่อท่าเตียนมาจากตำนานยักษ์วัดโพธิ์ตีกับยักษ์วัดอรุณจนพื้นราบเป็นหน้ากลอง',
        textEn: 'Did you know? "Tha Tien" comes from the legend of Wat Pho giants fighting Wat Arun giants—flattening the land!',
        lat: 13.746464089616756,
        lng: 100.49271387841858,
      ),
      TipDefinition(
        topicId: 'wp_chinese_statues',
        textTh: 'ตุ๊กตาหินจีนใหญ่ๆ ในวัด เคยใช้ถ่วงเรือสินค้าตอนกลับจากจีนสมัยรัชกาลที่ 3 นะครับ',
        textEn: 'Those big Chinese stone figures? Originally ship ballast from China during Rama III\'s trade era!',
        lat: 13.746464089616756,
        lng: 100.49271387841858,
      ),
    ],

    'wat_arun': [
      TipDefinition(
        topicId: 'wa_carriers',
        textTh: 'ลองดูฐานปรางค์ดีๆ ครับ มีอมนุษย์แบกตามลำดับ ยักษ์ชั้นล่าง ลิงชั้นกลาง เทวดาชั้นบน',
        textEn: 'Look closely at the prang base! Carriers in order: giants below, monkeys middle (funny faces!), devas above.',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
      TipDefinition(
        topicId: 'wa_taksin_bed',
        textTh: 'ที่วิหารน้อยมีพระแท่นบรรทมพระเจ้าตากสินครับ คลานลอดใต้แท่นเพื่อขอพรเรื่องชัยชนะ',
        textEn: 'In the small chapel: King Taksin\'s bed. Crawl under it for blessings of victory!',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
      TipDefinition(
        topicId: 'wa_prang',
        textTh: 'เครื่องเคลือบที่ประดับพระปรางค์เป็นเศษถ้วยชามจีนที่แตกจากเรือสินค้านะครับ เอามาตัดเรียงใหม่',
        textEn: 'The porcelain decorating the prang? Broken pieces from Chinese trade ships—cut and rearranged into flowers!',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
      TipDefinition(
        topicId: 'wa_main_buddha',
        textTh: 'พระประธานในพระอุโบสถ รัชกาลที่ 2 ทรงปั้นพระพักตร์ด้วยฝีพระหัตถ์ของพระองค์เองนะครับ',
        textEn: 'The main Buddha\'s face was personally sculpted by King Rama II himself!',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
      TipDefinition(
        topicId: 'wa_sunset',
        textTh: 'อยู่จนเย็นนะครับ พระอาทิตย์ตกที่นี่สวยมาก ข้ามไปฝั่งท่าเตียนถ่ายภาพได้เงาปรางค์เหมือนหลังเหรียญ 10 บาท',
        textEn: 'Stay until evening! Cross to Tha Tien for sunset—the silhouette matches the 10 baht coin!',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
      TipDefinition(
        topicId: 'wa_climb',
        textTh: 'ปีนพระปรางค์ขึ้นไปได้ครับ แต่บันไดชันมาก ตั้งใจให้เป็นแบบนั้นเพื่อเตือนว่าทางไปสวรรค์ยากลำบาก',
        textEn: 'You can climb the prang! Stairs are intentionally steep—reminding us the path to heaven is hard.',
        lat: 13.742742198190044,
        lng: 100.48391512951908,
      ),
    ],
  };

  /// Call when user enters a location's geofence (unlocked).
  /// First tip fires ~15s after arrival, then every [intervalMinutes] min.
  /// Idempotent — calling repeatedly for the same place won't restart.
  void startTipsForLocation(String locationId, {int intervalMinutes = 5}) {
    if (_activeLocation == locationId && _scheduledTip != null) {
      return;  // already running for this place
    }
    _activeLocation = locationId;
    _cancelScheduled();
    // First tip fires quickly so the user notices it
    _scheduleNextTip(locationId, intervalMinutes, firstDelaySeconds: 15);
  }

  /// Call when user leaves the location
  void stopTips() {
    _activeLocation = null;
    _cancelScheduled();
  }

  /// Reset session — clear "already shown" memory
  void resetSession() {
    _shownTips.clear();
  }

  void _scheduleNextTip(String locationId, int intervalMinutes,
      {int? firstDelaySeconds}) {
    final tips = _tipsLibrary[locationId];
    if (tips == null || tips.isEmpty) return;

    // Find first tip not yet shown
    TipDefinition? next;
    for (var tip in tips) {
      if (!_shownTips.contains(tip.topicId)) {
        next = tip;
        break;
      }
    }

    if (next == null) return;  // all shown

    final delay = firstDelaySeconds != null
        ? Duration(seconds: firstDelaySeconds)
        : Duration(minutes: intervalMinutes);

    _scheduledTip = Timer(delay, () {
      if (next == null) return;
      _shownTips.add(next.topicId);
      _tipController.add(TipMessage(
        topicId: next.topicId,
        locationId: locationId,
      ));
      // Schedule the rest at the normal interval
      _scheduleNextTip(locationId, intervalMinutes);
    });
  }

  /// Manually trigger first tip (useful for "just unlocked" moment)
  TipDefinition? getFirstUnshownTip(String locationId) {
    final tips = _tipsLibrary[locationId];
    if (tips == null || tips.isEmpty) return null;
    for (var tip in tips) {
      if (!_shownTips.contains(tip.topicId)) {
        _shownTips.add(tip.topicId);
        return tip;
      }
    }
    return null;
  }

  /// Get ALL tips for a location (used by map sheet to list everything)
  List<TipDefinition> getAllTips(String locationId) {
    return _tipsLibrary[locationId] ?? const [];
  }

  void _cancelScheduled() {
    _scheduledTip?.cancel();
    _scheduledTip = null;
  }

  @override
  void dispose() {
    _cancelScheduled();
    _tipController.close();
    super.dispose();
  }
}

class TipDefinition {
  final String topicId;
  final String textTh;
  final String textEn;
  final double lat; // ← Add latitude
  final double lng; // ← Add longitude

  const TipDefinition({
    required this.topicId,
    required this.textTh,
    required this.textEn,
    required this.lat,
    required this.lng,
  });

  String text(String lang) => lang == 'th' ? textTh : textEn;
}

class TipMessage {
  final String topicId;
  final String locationId;
  TipMessage({required this.topicId, required this.locationId});
}