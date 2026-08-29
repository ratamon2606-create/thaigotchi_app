import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../models/pet_state.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import '../services/rag_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';
import '../services/audio_availability_service.dart';
import '../services/tip_service.dart';
import '../widgets/connection_banner.dart';
import '../services/locations_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _settings = SettingsService();
  final _ble = BLEService();
  final _rag = LocalRAGService();
  final _voice = VoiceService();
  final _history = ChatHistoryService();
  final _audioAvail = AudioAvailabilityService();
  final _tips = TipService();
  StreamSubscription? _tipSub;
  final _locations = LocationsService();
  
  bool _isThinking = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    
    _initWelcome();
    
    _voice.addListener(_onVoiceUpdate);
    _settings.addListener(_onSettingsUpdate);
    _history.addListener(_onHistoryUpdate);
    
    // Listen for proactive tips from TipService
    _tipSub = _tips.tipStream.listen(_onTipReceived);
  }
  
  /// Inject a contextual tip into the chat as if pet sent it
  Future<void> _onTipReceived(TipMessage tip) async {
    final allTips = _tips.getAllTips(tip.locationId);
    final def = allTips.firstWhere(
      (t) => t.topicId == tip.topicId,
      orElse: () => allTips.first,
    );
    
    await _history.addMessage(ChatMessage(
      text: def.text(_settings.language),
      isPet: true,
      source: MessageSource.system,
      timestamp: DateTime.now(),
      locationId: tip.locationId,
      spokenByDevice: false,
      topicId: tip.topicId,   // ← เพิ่มบรรทัดนี้ (เก็บ topicId ของ tip)
    ));
  }

  /// Find the TipDefinition (with lat/lng) that matches a given message,
  /// if that message is a tip bubble.
  TipDefinition? _tipDefForMessage(ChatMessage msg) {
    if (msg.topicId == null || msg.locationId == null) return null;
    final allTips = _tips.getAllTips(msg.locationId!);
    for (final t in allTips) {
      if (t.topicId == msg.topicId) return t;
    }
    return null;
  }

  /// Open Google Maps (app if installed, else browser) at the given coords.
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch maps for: $lat, $lng');
    }
  }

  Future<void> _initWelcome() async {
    // Only add welcome on first launch
    if (_history.count == 0) {
      await _history.addMessage(ChatMessage(
        text: _settings.t('chat_welcome'),
        isPet: true,
        source: MessageSource.system,
        timestamp: DateTime.now(),
        spokenByDevice: true,  // boot welcome.wav already played
      ));
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voice.removeListener(_onVoiceUpdate);
    _settings.removeListener(_onSettingsUpdate);
    _history.removeListener(_onHistoryUpdate);
    _tipSub?.cancel();
    super.dispose();
  }

  void _onVoiceUpdate() {
    if (mounted) {
      setState(() {
        _isListening = _voice.isListening;
      });
    }
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  void _onHistoryUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  /// Process question → RAG → log + maybe speak
  Future<void> _processQuestion(
    String question, {
    required MessageSource source,
  }) async {
    if (question.trim().isEmpty) return;

    // Log user question
    await _history.addMessage(ChatMessage(
      text: question,
      isPet: false,
      source: source,
      timestamp: DateTime.now(),
    ));

    setState(() => _isThinking = true);

    // Show pet thinking
    if (_ble.isConnected) {
      _ble.setPose('thinking');
      
      // Voice source = play thinking filler from SD
      if (source == MessageSource.voice) {
        final fillerNum = (DateTime.now().millisecond % 3) + 1;
        _ble.playAudio('thinking_0$fillerNum');
      }
    }

    // Query RAG
    await Future.delayed(const Duration(milliseconds: 1200));
    final response = _rag.queryMulti(
      question,
      language: _settings.language,
    );

    if (!mounted) return;

    setState(() => _isThinking = false);

    // Decide: speak via device or text-only?
    final shouldSpeak = (source == MessageSource.voice);

    // Derive location from topic so the speak-button can find an intro file
    final introFile = _introFileForTopic(response.topicId);
    final locId = introFile?.replaceAll('_intro', '');

    // Log pet response
    await _history.addMessage(ChatMessage(
      text: response.text,
      isPet: true,
      source: source,
      timestamp: DateTime.now(),
      spokenByDevice: shouldSpeak,
      locationId: locId,
    ));

    if (shouldSpeak && _ble.isConnected) {
      // Play the location's intro story (which exists on SD)
      if (introFile != null && _audioAvail.hasAudio(introFile)) {
        _ble.setPose('talking');
        _ble.playAudio(introFile);
        Future.delayed(const Duration(seconds: 12), () {
          if (_ble.isConnected) _ble.setPose('idle');
        });
      } else {
        // No audio file available — go straight back to idle
        _ble.playAudio('got_it');
        Future.delayed(const Duration(seconds: 2), () {
          if (_ble.isConnected) _ble.setPose('idle');
        });
      }
    } else if (_ble.isConnected) {
      // Text-only reply — return to idle right away (was thinking)
      _ble.setPose('idle');
    }
  }

  /// Map a RAG topicId to its location's intro audio file (which IS on SD).
  /// e.g. wpk_history → wat_phra_kaew_intro,  wa_prang → wat_arun_intro
  String? _introFileForTopic(String? topicId) {
    if (topicId == null) return null;
    if (topicId.startsWith('wpk_') || topicId == 'wat_phra_kaew_intro') {
      return 'wat_phra_kaew_intro';
    }
    if (topicId.startsWith('wa_') || topicId == 'wat_arun_intro') {
      return 'wat_arun_intro';
    }
    if (topicId.startsWith('wp_') || topicId == 'wat_pho_intro') {
      return 'wat_pho_intro';
    }
    return null;
  }

  /// Find what topic_id matches a pet's message (for audio lookup)
  /// Stores topic on the message itself to avoid re-querying
  String? _findTopicForMessage(ChatMessage msg) {
    // Tip messages carry their own topicId with a matching WAV
    if (msg.topicId != null && _audioAvail.hasAudio(msg.topicId)) {
      return msg.topicId;
    }
    // If message has a locationId, that's an unlock card — use intro file
    if (msg.locationId != null) {
      return '${msg.locationId}_intro';
    }
    // Re-query RAG to find topic
    // This isn't perfect but works since RAG output is deterministic
    // for same input. We use the answer text reverse-matched against topics.
    return null;  // Fall through — let the speak handler deal with it
  }
  
  /// User tapped "speak this" button on a chat message
  /// Sends play command to ESP32 (uses WAV on SD card)
  Future<void> _speakMessage(int index) async {
    if (index < 0 || index >= _history.messages.length) return;
    final msg = _history.messages[index];
    
    if (!_ble.isConnected) return;  // No device, button shouldn't show anyway
    
    // Determine audio filename
    String? audioFile;
    if (msg.topicId != null && _audioAvail.hasAudio(msg.topicId)) {
      audioFile = msg.topicId;        // tip มีไฟล์เสียงของตัวเอง
    } else if (msg.locationId != null) {
      audioFile = '${msg.locationId}_intro';
    }
    
    // Only play if we have a confirmed WAV file
    if (audioFile != null && _audioAvail.hasAudio(audioFile)) {
      _ble.setPose('talking');
      _ble.playAudio(audioFile);
      await _history.markAsSpoken(index);
      
      Future.delayed(const Duration(seconds: 12), () {
        if (_ble.isConnected) _ble.setPose('idle');
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _processQuestion(text, source: MessageSource.text);
  }

  Future<void> _startVoiceInput() async {
    if (_isListening) return;

    if (_ble.isConnected) {
      _ble.setPose('thinking');
    }

    _voice.listen(timeout: const Duration(seconds: 30)).then((result) {
      if (result != null && result.isNotEmpty) {
        _processQuestion(result, source: MessageSource.voice);
      } else {
        if (_ble.isConnected) {
          _ble.setPose('idle');
        }
      }
    });
  }

  Future<void> _stopVoiceInput() async {
    if (!_isListening) return;
    await _voice.stopListening();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/chat_background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.cafeCream,
                        AppColors.cafeAccent.withValues(alpha: 0.5),
                        AppColors.cafeWallBrown.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: Container(color: AppColors.cafeCream.withValues(alpha: 0.5)),
          ),
          SafeArea(
            child: Column(
              children: [
                const ConnectionBanner(),
                _buildHeader(),
                Expanded(child: _buildMessages()),
                if (_isThinking) _buildThinkingIndicator(),
                if (_isListening) _buildListeningIndicator(),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 60, // Fixed height for the header area
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ─── 1. THE IMAGE BACKGROUND (Full Width) ───
          Positioned.fill(
            child: Image.asset(
              'assets/images/chat_header.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to red color if image fails to load
                return Container(color: AppColors.cafeBrickRed);
              },
            ),
          ),

          // ─── 2. THE TITLE TEXT (Lowered) ───
          Padding(
            padding: const EdgeInsets.only(top: 12.0), // Moves text slightly down
            child: Text(
              _settings.t('chat_header'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ChulabhornLikit',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    final messages = _history.messages;
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        
        // Unlock cards are special
        if (msg.source == MessageSource.unlock && msg.isPet) {
          return _UnlockCard(
            message: msg,
            location: msg.locationId != null
                ? _locations.getById(msg.locationId!)
                : null,
            isThai: _settings.isThai,
            onSpeak: () => _speakMessage(index),
          ).animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0);
        }
        
        // Show speak button only if:
        // 1. It's a pet reply
        // 2. Not already spoken
        // 3. Audio file exists on SD card
        final canSpeak = msg.isPet && 
            !msg.spokenByDevice && 
            _audioAvail.hasAudio(_findTopicForMessage(msg));

        // If this bubble is a tip, find its lat/lng so we can make it tappable
        final tipDef = _tipDefForMessage(msg);
        
        return _ChatBubble(
          message: msg,
          onSpeak: canSpeak ? () => _speakMessage(index) : null,
          onMapTap: tipDef != null
              ? () => _openGoogleMaps(tipDef.lat, tipDef.lng)
              : null,
          isThai: _settings.isThai,
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildPetAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cafeWallBrown.withValues(alpha: 0.6),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(
                        duration: 600.ms,
                        delay: (i * 200).ms,
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.2, 1.2),
                      )
                      .then()
                      .scale(
                        duration: 600.ms,
                        begin: const Offset(1.2, 1.2),
                        end: const Offset(0.6, 0.6),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.leafGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppColors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _voice.recognizedText.isEmpty
                  ? (_settings.isThai ? 'กำลังฟัง...' : 'Listening...')
                  : _voice.recognizedText,
              style: const TextStyle(
                fontFamily: 'ChulabhornLikit',
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cafeAccent,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/chat_avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.pets,
              size: 18,
              color: AppColors.cafeDeepBrown,
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _isListening ? _stopVoiceInput : _startVoiceInput,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_outlined,
                color: _isListening
                    ? AppColors.leafGreen
                    : AppColors.cafeWallBrown,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  fontFamily: 'ChulabhornLikit',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _settings.t('chat_hint'),
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.leafGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendTextMessage,
                icon: const Icon(
                  Icons.send,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ CHAT BUBBLE ============
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onSpeak;
  final VoidCallback? onMapTap;
  final bool isThai;

  const _ChatBubble({
    required this.message,
    this.onSpeak,
    this.onMapTap,
    required this.isThai,
  });

  @override
  Widget build(BuildContext context) {
    final isPet = message.isPet;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isPet ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPet) _buildAvatar(),
          if (isPet) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isPet
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isPet
                        ? AppColors.white.withValues(alpha: 0.95)
                        : AppColors.leafGreen,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isPet ? 4 : 16),
                      bottomRight: Radius.circular(isPet ? 16 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onMapTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSourceLabel(isPet),
                            Text(
                              message.text,
                              style: TextStyle(
                                fontFamily: 'ChulabhornLikit',
                                fontSize: 14,
                                height: 1.4,
                                color: isPet
                                    ? AppColors.cafeDeepBrown
                                    : AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontFamily: 'ChulabhornLikit',
                                    fontSize: 10,
                                    color: isPet
                                        ? AppColors.cafeWallBrown
                                        : AppColors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                if (onMapTap != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: isPet
                                        ? AppColors.cafeWallBrown
                                        : AppColors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    isThai ? 'แตะดูแผนที่' : 'Tap for map',
                                    style: TextStyle(
                                      fontFamily: 'ChulabhornLikit',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isPet
                                          ? AppColors.cafeWallBrown
                                          : AppColors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // "Speak via device" button (text-only pet replies)
                if (onSpeak != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onSpeak,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cafeAccent.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cafeWallBrown.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_up,
                            size: 14,
                            color: AppColors.cafeDeepBrown,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isThai ? 'ให้อุปกรณ์พูด' : 'Play via device',
                            style: const TextStyle(
                              fontFamily: 'ChulabhornLikit',
                              fontSize: 11,
                              color: AppColors.cafeDeepBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceLabel(bool isPet) {
    String? label;
    IconData? icon;
    
    if (isPet) {
      if (message.spokenByDevice) {
        icon = Icons.volume_up;
        label = isThai ? 'อุปกรณ์พูดแล้ว' : 'Spoken';
      } else if (message.source == MessageSource.text) {
        icon = Icons.chat_bubble_outline;
        label = isThai ? 'ตอบในแชท' : 'Text reply';
      }
    } else {
      if (message.source == MessageSource.voice) {
        icon = Icons.mic;
        label = isThai ? 'เสียง' : 'Voice';
      }
    }
    
    if (label == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isPet
                ? AppColors.cafeWallBrown
                : AppColors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ChulabhornLikit',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isPet
                  ? AppColors.cafeWallBrown
                  : AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cafeAccent,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/chat_avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.pets,
              size: 18,
              color: AppColors.cafeDeepBrown,
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

// ============ UNLOCK CARD ============
class _UnlockCard extends StatelessWidget {
  final ChatMessage message;
  final CulturalLocation? location;
  final bool isThai;
  final VoidCallback onSpeak;

  const _UnlockCard({
    required this.message,
    required this.location,
    required this.isThai,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.leafGreen.withValues(alpha: 0.95),
              AppColors.leafGreen.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.leafGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_open,
                  color: AppColors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isThai ? 'ปลดล็อกแล้ว!' : 'Unlocked!',
                  style: const TextStyle(
                    fontFamily: 'ChulabhornLikit',
                    fontSize: 12,
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (location != null)
              Text(
                isThai ? location!.nameTh : location!.nameEn,
                style: const TextStyle(
                  fontFamily: 'ChulabhornLikit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              message.text,
              style: TextStyle(
                fontFamily: 'ChulabhornLikit',
                fontSize: 13,
                height: 1.5,
                color: AppColors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.volume_up,
                  size: 14,
                  color: AppColors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  message.spokenByDevice
                      ? (isThai ? 'อุปกรณ์เล่าแล้ว' : 'Story told')
                      : (isThai ? 'รอเล่า' : 'Pending'),
                  style: TextStyle(
                    fontFamily: 'ChulabhornLikit',
                    fontSize: 11,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                if (!message.spokenByDevice)
                  GestureDetector(
                    onTap: onSpeak,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isThai ? 'เล่าอีกครั้ง' : 'Replay',
                        style: const TextStyle(
                          fontFamily: 'ChulabhornLikit',
                          fontSize: 11,
                          color: AppColors.leafGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}