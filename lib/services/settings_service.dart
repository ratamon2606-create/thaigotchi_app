import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();
  
  late SharedPreferences _prefs;
  bool _initialized = false;
  
  // Settings
  String _petName = 'มฤคนที';
  String _language = 'th';   // 'th' or 'en'
  bool _shareData = false;
  double _audioVolume = 0.7;
  bool _hasAdoptedPet = false;
  
  String get petName => _petName;
  String get language => _language;
  String get languageCode => _language == 'th' ? 'th-TH' : 'en-US';
  bool get isThai => _language == 'th';
  bool get isEnglish => _language == 'en';
  bool get shareData => _shareData;
  double get audioVolume => _audioVolume;
  bool get hasAdoptedPet => _hasAdoptedPet;
  
  Future<void> init() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    _petName = _prefs.getString('petName') ?? 'มฤคนที';
    _language = _prefs.getString('language') ?? 'th';
    _shareData = _prefs.getBool('shareData') ?? false;
    _audioVolume = _prefs.getDouble('audioVolume') ?? 0.7;
    _hasAdoptedPet = _prefs.getBool('hasAdoptedPet') ?? false;
    
    _initialized = true;
    notifyListeners();
  }
  
  Future<void> setPetName(String name) async {
    _petName = name;
    await _prefs.setString('petName', name);
    notifyListeners();
  }
  
  Future<void> setLanguage(String lang) async {
    if (lang != 'th' && lang != 'en') return;
    _language = lang;
    await _prefs.setString('language', lang);
    notifyListeners();
  }
  
  Future<void> toggleLanguage() async {
    await setLanguage(_language == 'th' ? 'en' : 'th');
  }
  
  Future<void> setShareData(bool value) async {
    _shareData = value;
    await _prefs.setBool('shareData', value);
    notifyListeners();
  }
  
  Future<void> setAudioVolume(double value) async {
    _audioVolume = value;
    await _prefs.setDouble('audioVolume', value);
    notifyListeners();
  }
  
  Future<void> setHasAdoptedPet(bool value) async {
    _hasAdoptedPet = value;
    await _prefs.setBool('hasAdoptedPet', value);
    notifyListeners();
  }
  
  Future<void> clearAll() async {
    await _prefs.clear();
    _petName = 'มฤคนที';
    _language = 'th';
    _shareData = false;
    _audioVolume = 0.7;
    _hasAdoptedPet = false;
    notifyListeners();
  }
  
  // ============ STRINGS (i18n) ============
  
  String t(String key) {
    final strings = _language == 'th' ? _thStrings : _enStrings;
    return strings[key] ?? key;
  }
  
  static const Map<String, String> _thStrings = {
    'app_name': 'มฤคนที',
    'adopt_button': 'รับเลี้ยง',
    'pet_name_label': 'ตั้งชื่อให้น้อง',
    'pet_description': 'ครึ่งกวางครึ่งปลาแห่งป่าหิมพานต์',
    'searching_title': 'กำลังค้นหามฤคนที',
    'searching_subtitle': 'กรุณาเปิดอุปกรณ์ของคุณ',
    'connecting': 'กำลังเชื่อมต่อ',
    'connected': 'เชื่อมต่อแล้ว',
    'retry': 'ลองใหม่อีกครั้ง',
    'tab_device': 'อุปกรณ์',
    'tab_chat': 'แชท',
    'tab_map': 'แผนที่',
    'connection_label': 'การเชื่อมต่อ',
    'battery_label': 'แบตเตอรี่',
    'location_label': 'ตำแหน่ง',
    'chat_header': 'สนทนา',
    'chat_hint': 'พิมพ์คำถาม...',
    'chat_welcome': 'สวัสดีครับ! ผมเป็นมฤคนที\nเพื่อนนำเที่ยวที่จะคอยเล่าเรื่องราวให้คุณฟัง',
    'map_header': 'สถานที่สำคัญ',
    'map_progress': 'สำรวจแล้ว',
    'map_locked': 'ไปเยี่ยมสถานที่นี้\nเพื่อปลดล็อกเรื่องเล่า',
    'map_unlocked': 'ปลดล็อกแล้ว ✨',
    'settings_title': 'การตั้งค่า',
    'settings_privacy': 'ข้อมูลและความเป็นส่วนตัว',
    'settings_share_data': 'ช่วยพัฒนามฤคนที',
    'settings_share_data_desc': 'แชร์ข้อมูลแบบไม่ระบุตัวตน',
    'settings_history': 'ประวัติการถาม',
    'settings_history_desc': 'ดูข้อมูลที่จัดเก็บ',
    'settings_clear': 'ลบประวัติทั้งหมด',
    'settings_device': 'อุปกรณ์',
    'settings_rename': 'เปลี่ยนชื่อน้อง',
    'settings_ble': 'จัดการอุปกรณ์ BLE',
    'settings_audio': 'เสียง',
    'settings_audio_desc': 'ความดัง, ภาษา',
    'settings_language': 'ภาษา',
    'settings_about': 'เกี่ยวกับ',
    'settings_version': 'เวอร์ชัน',
    'settings_university': 'มหาวิทยาลัยเกษตรศาสตร์',
    'settings_reset': 'เริ่มต้นใหม่',
    'cancel': 'ยกเลิก',
    'confirm': 'ยืนยัน',
    'delete': 'ลบ',
    'thai': 'ไทย',
    'english': 'อังกฤษ',
  };
  
  static const Map<String, String> _enStrings = {
    'app_name': 'Maruknathi',
    'adopt_button': 'Adopt',
    'pet_name_label': 'Name your pet',
    'pet_description': 'Half-deer half-fish of the Himmaphan forest',
    'searching_title': 'Searching for Maruknathi',
    'searching_subtitle': 'Please turn on your device',
    'connecting': 'Connecting',
    'connected': 'Connected',
    'retry': 'Try again',
    'tab_device': 'Device',
    'tab_chat': 'Chat',
    'tab_map': 'Map',
    'connection_label': 'Connection',
    'battery_label': 'Battery',
    'location_label': 'Location',
    'chat_header': 'Chat',
    'chat_hint': 'Type your question...',
    'chat_welcome': 'Hello! I\'m Maruknathi, a Himmaphan creature\nwho loves telling stories',
    'map_header': 'Cultural Landmarks',
    'map_progress': 'Explored',
    'map_locked': 'Visit this place\nto unlock the story',
    'map_unlocked': 'Unlocked ✨',
    'settings_title': 'Settings',
    'settings_privacy': 'Data & Privacy',
    'settings_share_data': 'Help improve Maruknathi',
    'settings_share_data_desc': 'Share anonymous data',
    'settings_history': 'Question history',
    'settings_history_desc': 'View stored data',
    'settings_clear': 'Clear all history',
    'settings_device': 'Device',
    'settings_rename': 'Rename pet',
    'settings_ble': 'BLE device management',
    'settings_audio': 'Audio',
    'settings_audio_desc': 'Volume, language',
    'settings_language': 'Language',
    'settings_about': 'About',
    'settings_version': 'Version',
    'settings_university': 'Kasetsart University',
    'settings_reset': 'Start over',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'thai': 'Thai',
    'english': 'English',
  };
}