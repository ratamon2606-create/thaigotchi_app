/// Tracks which audio files are available on the ESP32 SD card.
/// 
/// Maintains a whitelist of topic_id → SD filename mappings.
/// Used by chat UI to decide whether to show "Play via device" button.
class AudioAvailabilityService {
  static final AudioAvailabilityService _instance = 
      AudioAvailabilityService._internal();
  factory AudioAvailabilityService() => _instance;
  AudioAvailabilityService._internal();
  
  /// Set of topic_ids that have corresponding WAV files on SD card.
  /// Must match the WAV filenames you actually generated and copied.
  static const Set<String> _availableAudio = {
    // System sounds
    'welcome',
    'listening',
    'got_it',
    'thinking_01',
    'thinking_02',
    'thinking_03',
    
    // Location intros (full stories)
    'wat_phra_kaew_intro',
    'wat_arun_intro',
    'wat_pho_intro',
    "wpk_giants",
    "wpk_murals",
    "wpk_hidden_art",
    "wpk_chedi",
    "wpk_angkor",
    "wpk_holy_water",

    "wp_108_bowls",
    "wp_real_giants",
    "wp_pagodas",
    "wp_massage",
    "wp_tha_tien",
    "wp_chinese_statues",

    "wa_carriers",
    "wa_taksin_bed",
    "wa_prang",
    "wa_main_buddha",
    "wa_sunset",
    "wa_climb",
    
    // Add more here as you generate more WAV files:
    // 'wpk_history',
    // 'wpk_buddha',
    // 'wa_history',
    // ...
  };
  
  /// Check if a given topic_id has a WAV file available
  bool hasAudio(String? topicId) {
    if (topicId == null || topicId.isEmpty) return false;
    return _availableAudio.contains(topicId);
  }
}