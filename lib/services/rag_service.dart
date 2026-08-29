import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/pet_state.dart';

/// Local RAG (Retrieval-Augmented Generation) Service
/// 
/// v5.0 Features:
/// - Fuzzy matching for typos (Levenshtein distance)
/// - Synonym expansion
/// - Context awareness (remembers last topic discussed)
/// - Multi-keyword scoring with phrase boost
/// - Question type detection (what/when/how/why)
class LocalRAGService {
  static final LocalRAGService _instance = LocalRAGService._internal();
  factory LocalRAGService() => _instance;
  LocalRAGService._internal();
  
  Map<String, dynamic> _content = {};
  bool _initialized = false;
  
  // Context tracking - last topic + location discussed
  String? _lastTopicId;
  String? _lastLocationId;
  DateTime? _lastQueryTime;
  
  // Synonym table — Thai/English
  static const Map<String, List<String>> _synonyms = {
    // Time
    'สร้าง': ['ก่อตั้ง', 'สถาปนา', 'สร้างขึ้น', 'ก่อสร้าง'],
    'เก่า': ['โบราณ', 'แก่', 'เก่าแก่', 'ยาวนาน'],
    'ปี': ['พ.ศ.', 'ค.ศ.', 'ศักราช'],
    'เมื่อไหร่': ['ตอนไหน', 'วันไหน', 'เมื่อใด', 'ปีไหน'],
    
    // Visit
    'เที่ยว': ['ไป', 'เยี่ยมชม', 'ดู', 'ชม', 'แวะ', 'ทัวร์'],
    'แต่งตัว': ['แต่งกาย', 'เสื้อผ้า', 'การแต่ง', 'แต่ง'],
    'เปิด': ['เปิดทำการ', 'ทำการ', 'เปิดให้เข้า'],
    'ค่า': ['ราคา', 'ตั๋ว', 'บัตร', 'ค่าเข้า'],
    
    // Buddha
    'พระพุทธรูป': ['พระประธาน', 'พระ', 'องค์พระ'],
    'พระแก้ว': ['พระแก้วมรกต', 'มรกต', 'พระมรกต'],
    'พระนอน': ['พระพุทธไสยาส', 'ไสยาส', 'พระไสยาส'],
    
    // Architecture
    'พระปรางค์': ['ปรางค์', 'พระเจดีย์ปรางค์'],
    'เจดีย์': ['สถูป', 'พระเจดีย์'],
    'สูง': ['ความสูง', 'สูงเท่าไหร่', 'สูงแค่ไหน'],
    
    // Royalty
    'รัชกาล': ['ร.', 'พระเจ้าอยู่หัว', 'พระมหากษัตริย์', 'กษัตริย์'],
    'รัชกาลที่ 1': ['ร.1', 'รัชกาลที่1', 'ร.๑'],
    'รัชกาลที่ 3': ['ร.3', 'รัชกาลที่3', 'ร.๓'],
    
    // Story request triggers
    'เล่า': ['บอก', 'พูด', 'อธิบาย'],
    'เรื่อง': ['ประวัติ', 'ความเป็นมา', 'รายละเอียด'],
    'รู้จัก': ['คือ', 'อะไร'],
    
    // Conversational shortcuts
    'มัน': [],  // pronouns to ignore
    'อันนี้': [],
    'อันนั้น': [],
    
    // English
    'temple': ['wat', 'monastery', 'shrine'],
    'buddha': ['buddha statue', 'image'],
    'when': ['date', 'year', 'time'],
    'where': ['location', 'place'],
    'how': ['way', 'method'],
    'visit': ['go', 'see', 'tour'],
  };
  
  // Question type markers
  static const Map<String, List<String>> _questionMarkers = {
    'when': ['เมื่อไหร่', 'ปีไหน', 'เมื่อใด', 'ตอนไหน', 'when'],
    'where': ['ที่ไหน', 'อยู่ไหน', 'where'],
    'how': ['ยังไง', 'อย่างไร', 'how'],
    'why': ['ทำไม', 'เพราะอะไร', 'why'],
    'what': ['อะไร', 'คือ', 'what'],
    'who': ['ใคร', 'who'],
    'story': ['เล่า', 'บอก', 'เรื่อง', 'tell'],
  };
  
  // Context keywords - point to previous topic
  static const List<String> _contextRefs = [
    'มัน', 'อันนี้', 'อันนั้น', 'ที่นี่', 'ที่นั่น',
    'แล้ว', 'อีก', 'อะไรอีก', 'อีกล่ะ',
    'it', 'this', 'that', 'there', 'else',
  ];

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      String jsonStr = await rootBundle
          .loadString('assets/data/rag_content.json');
      _content = jsonDecode(jsonStr);
      _initialized = true;
    } catch (e) {
      _initialized = true;
      _content = {'topics': []};
    }
  }
  
  /// Reset context (e.g. when switching screens or sessions)
  void resetContext() {
    _lastTopicId = null;
    _lastLocationId = null;
    _lastQueryTime = null;
  }
  
  /// Set location context (called from map screen when near a location)
  void setLocationContext(String locationId) {
    _lastLocationId = locationId;
  }
  
  RAGResponse query(
    String question, {
    String language = 'th',
    String? contextLocationId,
  }) {
    if (!_initialized) {
      return _randomFallback(language);
    }
    
    final normalized = _normalize(question);
    
    // Greeting check
    if (_isGreeting(normalized, language)) {
      return _randomGreeting(language);
    }
    
    // Detect context reference ("เล่าอีก", "อะไรอีก")
    bool isContextRef = _hasContextReference(normalized);
    
    // If only context ref + no other content → use last topic's RELATED topic
    if (isContextRef && _lastLocationId != null) {
      final related = _findRelatedTopic(_lastLocationId!, _lastTopicId, language);
      if (related != null) {
        _updateContext(related);
        return _topicToResponse(related, language);
      }
    }
    
    // Detect question type for boost
    String? questionType = _detectQuestionType(normalized);
    
    // Effective location context: explicit or remembered
    String? effectiveLocation = contextLocationId ?? _lastLocationId;
    
    // Score all topics
    final topics = (_content['topics'] as List?) ?? [];
    Map<String, dynamic>? bestTopic;
    double bestScore = 0;
    
    for (var topic in topics) {
      final t = topic as Map<String, dynamic>;
      double score = _scoreTopic(
        normalized,
        t,
        language: language,
        contextLocationId: effectiveLocation,
        questionType: questionType,
      );
      
      if (score > bestScore) {
        bestScore = score;
        bestTopic = t;
      }
    }
    
    // Minimum threshold to avoid garbage matches
    if (bestTopic == null || bestScore < 0.3) {
      return _randomFallback(language);
    }
    
    _updateContext(bestTopic);
    return _topicToResponse(bestTopic, language);
  }

  /// Like query() but returns multiple relevant topics when several match.
  /// Useful when a keyword (e.g. "บันได") appears in more than one topic.
  RAGResponse queryMulti(
    String question, {
    String language = 'th',
    String? contextLocationId,
  }) {
    if (!_initialized) return _randomFallback(language);

    final normalized = _normalize(question);

    if (_isGreeting(normalized, language)) return _randomGreeting(language);

    // Context reference handling (same as query)
    bool isContextRef = _hasContextReference(normalized);
    if (isContextRef && _lastLocationId != null) {
      final related = _findRelatedTopic(_lastLocationId!, _lastTopicId, language);
      if (related != null) {
        _updateContext(related);
        return _topicToResponse(related, language);
      }
    }

    String? questionType = _detectQuestionType(normalized);
    String? effectiveLocation = contextLocationId ?? _lastLocationId;

    // Score ALL topics, keep ones above threshold
    final topics = (_content['topics'] as List?) ?? [];
    final scored = <MapEntry<Map<String, dynamic>, double>>[];

    for (var topic in topics) {
      final t = topic as Map<String, dynamic>;
      double score = _scoreTopic(
        normalized, t,
        language: language,
        contextLocationId: effectiveLocation,
        questionType: questionType,
      );
      if (score >= 0.3) scored.add(MapEntry(t, score));
    }

    if (scored.isEmpty) return _randomFallback(language);

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Keep topics whose score is close to the best (within 35%), max 3
    final topScore = scored.first.value;
    final close = scored
        .where((e) => e.value >= topScore * 0.65)
        .take(3)
        .toList();

    _updateContext(close.first.key);

    // Single strong match → behave like normal query
    if (close.length == 1) {
      return _topicToResponse(close.first.key, language);
    }

    // Multiple matches → combine into one answer
    final answerField = 'answer_$language';
    final intro = language == 'th'
        ? 'เรื่องนี้มี ${close.length} ส่วนที่น่าสนใจครับ:\n\n'
        : 'There are ${close.length} related parts:\n\n';

    final buffer = StringBuffer(intro);
    for (int i = 0; i < close.length; i++) {
      final ans = close[i].key[answerField] ??
          close[i].key['answer_th'] ?? '';
      buffer.write('${i + 1}. $ans');
      if (i < close.length - 1) buffer.write('\n\n');
    }

    return RAGResponse(
      text: buffer.toString(),
      audioFile: close.first.key['audio_file'] as String?,
      topicId: close.first.key['id'] as String?,
      confidence: 0.8,
    );
  }
  
  void _updateContext(Map<String, dynamic> topic) {
    _lastTopicId = topic['id'] as String?;
    final loc = topic['location_id'] as String?;
    if (loc != null) {
      _lastLocationId = loc;
    }
    _lastQueryTime = DateTime.now();
  }
  
  RAGResponse _topicToResponse(Map<String, dynamic> topic, String language) {
    final answerField = 'answer_$language';
    String answer = topic[answerField] ?? topic['answer_th'] ?? '';
    
    return RAGResponse(
      text: answer,
      audioFile: topic['audio_file'] as String?,
      topicId: topic['id'] as String?,
      confidence: 0.8,
    );
  }
  
  String getLocationStory(String locationId, String language) {
    if (!_initialized) return '';
    
    // Find location intro topic
    final topics = (_content['topics'] as List?) ?? [];
    for (var topic in topics) {
      final t = topic as Map<String, dynamic>;
      if (t['location_id'] == locationId && t['is_intro'] == true) {
        final field = 'answer_$language';
        return t[field] ?? t['answer_th'] ?? '';
      }
    }
    
    // Fallback: find any topic about this location
    for (var topic in topics) {
      final t = topic as Map<String, dynamic>;
      if (t['location_id'] == locationId) {
        final field = 'answer_$language';
        return t[field] ?? t['answer_th'] ?? '';
      }
    }
    
    return language == 'th'
        ? 'ยินดีต้อนรับสู่สถานที่นี้ครับ'
        : 'Welcome to this place';
  }
  
  // ===== Helpers =====
  
  String _normalize(String text) {
    return text.toLowerCase().trim();
  }
  
  bool _isGreeting(String text, String language) {
    final greetings = language == 'th'
        ? ['สวัสดี', 'หวัดดี', 'ไง', 'hello', 'hi']
        : ['hello', 'hi', 'hey', 'greetings'];
    
    return greetings.any((g) => text.contains(g));
  }
  
  bool _hasContextReference(String text) {
    return _contextRefs.any((ref) => text.contains(ref));
  }
  
  String? _detectQuestionType(String text) {
    for (var entry in _questionMarkers.entries) {
      if (entry.value.any((m) => text.contains(m))) {
        return entry.key;
      }
    }
    return null;
  }
  
  /// Find a topic related to a location, excluding one we just discussed
  Map<String, dynamic>? _findRelatedTopic(
    String locationId,
    String? excludeTopicId,
    String language,
  ) {
    final topics = (_content['topics'] as List?) ?? [];
    final candidates = <Map<String, dynamic>>[];
    
    for (var topic in topics) {
      final t = topic as Map<String, dynamic>;
      if (t['location_id'] == locationId && 
          t['id'] != excludeTopicId &&
          t['is_intro'] != true) {
        candidates.add(t);
      }
    }
    
    if (candidates.isEmpty) return null;
    return candidates[Random().nextInt(candidates.length)];
  }
  
  /// Expand a word with its synonyms
  List<String> _expandWithSynonyms(String word) {
    final result = [word];
    if (_synonyms.containsKey(word)) {
      result.addAll(_synonyms[word]!);
    }
    // Reverse lookup - if word IS a synonym, find the base
    for (var entry in _synonyms.entries) {
      if (entry.value.contains(word)) {
        result.add(entry.key);
        result.addAll(entry.value);
      }
    }
    return result.toSet().toList();
  }
  
  /// Simple fuzzy match - allows small typos
  bool _fuzzyContains(String text, String keyword) {
    // Exact match first
    if (text.contains(keyword)) return true;
    
    // For short keywords (<4 chars) don't allow fuzzy
    if (keyword.length < 4) return false;
    
    // Allow 1 char difference for words >= 4 chars
    // Slide a window across text
    final keyLen = keyword.length;
    for (int i = 0; i <= text.length - keyLen + 1; i++) {
      final end = min(i + keyLen + 1, text.length);
      final sub = text.substring(i, end);
      if (_levenshteinDistance(sub, keyword) <= 1) {
        return true;
      }
    }
    return false;
  }
  
  /// Levenshtein distance - count edit operations to transform a → b
  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    
    final v0 = List<int>.filled(b.length + 1, 0);
    final v1 = List<int>.filled(b.length + 1, 0);
    
    for (int i = 0; i <= b.length; i++) {
      v0[i] = i;
    }
    
    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce(min);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    
    return v1[b.length];
  }
  
  double _scoreTopic(
    String text,
    Map<String, dynamic> topic, {
    required String language,
    String? contextLocationId,
    String? questionType,
  }) {
    final keywordsField = 'keywords_${language}';
    final rawKeywords = (topic[keywordsField] as List?)?.cast<String>() ?? [];
    if (rawKeywords.isEmpty) return 0;
    
    double score = 0;
    int matched = 0;
    int strongMatches = 0;  // exact match of long keyword
    
    for (String keyword in rawKeywords) {
      final lowerKey = keyword.toLowerCase();
      
      // Expand keyword with synonyms
      final variations = _expandWithSynonyms(lowerKey);
      
      for (String variant in variations) {
        // Exact match (highest score)
        if (text.contains(variant)) {
          matched++;
          double weight = variant.length / 5.0;
          if (variant.contains(' ')) weight *= 1.5;
          if (variant.length >= 5) strongMatches++;

          // Boost specific-entity keywords (the actual subject asked about)
          // Place names are context; specific things (ยักษ์/บันได) are the topic
          final isEntity = (topic['entity_keywords_$language'] as List?)
              ?.cast<String>()
              .any((e) => e.toLowerCase() == variant) ?? false;
          if (isEntity) weight *= 3.0;   // strong boost for the real subject

          score += weight;
          break;
        }
        
        // Fuzzy match (lower score)
        if (variant.length >= 4 && _fuzzyContains(text, variant)) {
          matched++;
          score += variant.length / 8.0;  // half-weight for fuzzy
          break;
        }
      }
    }
    
    if (matched == 0) return 0;
    
    // Normalize by question length (avoid bias toward long questions)
    double normalizedScore = score / max(text.length / 15.0, 1.0);
    
    // Context boosts
    if (contextLocationId != null &&
        topic['location_id'] == contextLocationId) {
      normalizedScore *= 1.6;
    }
    
    // Question type alignment boost
    final topicType = topic['question_type'] as String?;
    if (questionType != null && topicType == questionType) {
      normalizedScore *= 1.3;
    }
    
    // Multiple strong matches = much higher confidence
    if (strongMatches >= 2) normalizedScore *= 1.4;
    
    return normalizedScore;
  }
  
  RAGResponse _randomGreeting(String language) {
    final greetings = (_content['greetings_$language'] as List?)
        ?.cast<String>() ?? ['Hello'];
    final text = greetings[Random().nextInt(greetings.length)];
    return RAGResponse(
      text: text,
      topicId: 'greeting',
      confidence: 1.0,
    );
  }
  
  RAGResponse _randomFallback(String language) {
    final fallbacks = (_content['fallbacks_$language'] as List?)
        ?.cast<String>() ?? ['Sorry, I don\'t understand'];
    final text = fallbacks[Random().nextInt(fallbacks.length)];
    return RAGResponse(
      text: text,
      topicId: null,  // no topic = no audio playback
      confidence: 0.0,
    );
  }
}