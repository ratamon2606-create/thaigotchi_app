import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();
  
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  
  bool _ttsInitialized = false;
  bool _sttInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  Completer<String?>? _listenCompleter;
  String _currentLanguage = 'th-TH';
  String _recognizedText = '';
  
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  bool get ttsReady => _ttsInitialized;
  
  Future<void> init({String language = 'th-TH'}) async {
    _currentLanguage = language;
    await _initTTS();
    await _initSTT();
  }
  
  // ============ TTS ============
  
  Future<void> _initTTS() async {
    try {
      // Set language first
      var languages = await _tts.getLanguages;
      debugPrint('Available TTS languages: $languages');
      
      // Try to set Thai, fallback if not available
      try {
        await _tts.setLanguage(_currentLanguage);
      } catch (e) {
        debugPrint('Could not set $_currentLanguage, trying th-TH: $e');
        try {
          await _tts.setLanguage('th-TH');
        } catch (e2) {
          debugPrint('Falling back to en-US: $e2');
          await _tts.setLanguage('en-US');
        }
      }
      
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.1);
      await _tts.setVolume(1.0);
      
      // Critical: wait for speak to complete + set queue mode
      await _tts.awaitSpeakCompletion(true);
      
      // Android only — but harmless on iOS
      try {
        await _tts.setQueueMode(0);  // flush queue, don't queue up
      } catch (_) {}
      
      // Engine selection (Android) — try Google TTS first
      try {
        var engines = await _tts.getEngines;
        debugPrint('TTS engines available: $engines');
        if (engines is List && engines.contains('com.google.android.tts')) {
          await _tts.setEngine('com.google.android.tts');
          debugPrint('✅ Using Google TTS engine');
        }
      } catch (e) {
        debugPrint('Engine select skipped: $e');
      }
      
      // Android: wait for completion
      if (await _tts.isLanguageAvailable(_currentLanguage)) {
        debugPrint('✅ $_currentLanguage available');
      }
      
      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('❌ TTS error: $msg');
      });
      
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _ttsInitialized = true;
      debugPrint('✅ TTS initialized: $_currentLanguage');
    } catch (e) {
      debugPrint('❌ TTS init error: $e');
    }
  }
  
  Future<void> speak(String text) async {
    if (!_ttsInitialized) {
      debugPrint('TTS not initialized, trying again...');
      await _initTTS();
    }
    
    if (text.trim().isEmpty) {
      debugPrint('Empty text, skipping speak');
      return;
    }
    
    try {
      // Stop any ongoing speech
      if (_isSpeaking) {
        await _tts.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      debugPrint('🔊 Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      var result = await _tts.speak(text);
      debugPrint('Speak result: $result');
    } catch (e) {
      debugPrint('❌ Speak error: $e');
    }
  }
  
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      notifyListeners();
    }
  }
  
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    if (_ttsInitialized) {
      try {
        await _tts.setLanguage(language);
      } catch (e) {
        debugPrint('setLanguage error: $e');
      }
    }
  }
  
  // ============ STT ============
  
  Future<void> _initSTT() async {
    try {
      _sttInitialized = await _stt.initialize(
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('STT error: ${error.errorMsg}');
          _isListening = false;
          notifyListeners();
        },
      );
      debugPrint('✅ STT initialized: $_sttInitialized');
    } catch (e) {
      debugPrint('❌ STT init error: $e');
    }
  }
  
  Future<String?> listen({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_sttInitialized) {
      await _initSTT();
    }
    if (!_sttInitialized) return null;
    
    final completer = Completer<String?>();
    _listenCompleter = completer;
    _recognizedText = '';
    _isListening = true;
    notifyListeners();
    
    try {
      await _stt.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
          if (result.finalResult) {
            if (!completer.isCompleted) {
              completer.complete(_recognizedText);
            }
            _isListening = false;
            _listenCompleter = null;
            notifyListeners();
          }
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        localeId: _currentLanguage,
        cancelOnError: true,
        partialResults: true,
      );
      
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          _stt.stop();
          _isListening = false;
          notifyListeners();
          completer.complete(_recognizedText.isEmpty ? null : _recognizedText);
        }
        _listenCompleter = null;
      });
      
      return completer.future;
    } catch (e) {
      debugPrint('Listen error: $e');
      _isListening = false;
      notifyListeners();
      return null;
    }
  }
  
  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
      notifyListeners();
      // Complete the pending listen() future so the caller gets the result
      // (button released before STT fired its own finalResult)
      if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
        _listenCompleter!.complete(
          _recognizedText.isEmpty ? null : _recognizedText,
        );
      }
      _listenCompleter = null;
    }
  }
  
  Future<bool> isAvailable() async => _stt.isAvailable;
}