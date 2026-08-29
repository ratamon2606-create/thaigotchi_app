import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_state.dart';

/// Persists chat messages across sessions
/// Stores last 200 messages in shared_preferences
class ChatHistoryService extends ChangeNotifier {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();
  
  static const String _storageKey = 'chat_history_v1';
  static const int _maxMessages = 200;
  
  List<ChatMessage> _messages = [];
  bool _initialized = false;
  
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int get count => _messages.length;
  
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];
      
      _messages = stored.map((jsonStr) {
        try {
          return ChatMessage.fromJson(jsonDecode(jsonStr));
        } catch (e) {
          return null;
        }
      }).whereType<ChatMessage>().toList();
      
      _initialized = true;
      debugPrint('✅ Loaded ${_messages.length} chat messages');
    } catch (e) {
      debugPrint('❌ Chat history init: $e');
    }
  }
  
  Future<void> addMessage(ChatMessage message) async {
    _messages.add(message);
    
    // Keep only last N messages
    if (_messages.length > _maxMessages) {
      _messages = _messages.sublist(_messages.length - _maxMessages);
    }
    
    await _persist();
    notifyListeners();
  }
  
  Future<void> markAsSpoken(int index) async {
    if (index < 0 || index >= _messages.length) return;
    _messages[index] = _messages[index].copyWith(spokenByDevice: true);
    await _persist();
    notifyListeners();
  }
  
  Future<void> clear() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }
  
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _messages.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList(_storageKey, encoded);
    } catch (e) {
      debugPrint('❌ Chat persist: $e');
    }
  }
}