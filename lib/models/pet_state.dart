/// Device state — สถานะ Thaigotchi device
class DeviceState {
  final String name;
  final bool isOn;
  final String currentPose;
  
  const DeviceState({
    this.name = 'มฤคนที',
    this.isOn = false,
    this.currentPose = 'idle',
  });
  
  factory DeviceState.fromJson(Map<String, dynamic> json) {
    return DeviceState(
      name: json['name'] ?? 'มฤคนที',
      isOn: json['on'] ?? false,
      currentPose: json['pose'] ?? 'idle',
    );
  }
  
  DeviceState copyWith({
    String? name,
    bool? isOn,
    String? currentPose,
  }) {
    return DeviceState(
      name: name ?? this.name,
      isOn: isOn ?? this.isOn,
      currentPose: currentPose ?? this.currentPose,
    );
  }
}

class GPSData {
  final double latitude;
  final double longitude;
  final bool fixed;
  final int satellites;
  
  const GPSData({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.fixed = false,
    this.satellites = 0,
  });
  
  factory GPSData.fromJson(Map<String, dynamic> json) {
    return GPSData(
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lng'] ?? 0.0).toDouble(),
      fixed: json['fix'] ?? false,
      satellites: json['sats'] ?? 0,
    );
  }
  
  bool get isValid => fixed && latitude != 0.0 && longitude != 0.0;
}

enum ThaigotchiConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

extension ThaigotchiConnectionStateExt on ThaigotchiConnectionState {
  String displayTextTH() {
    switch (this) {
      case ThaigotchiConnectionState.disconnected: return 'ไม่ได้เชื่อมต่อ';
      case ThaigotchiConnectionState.scanning: return 'กำลังค้นหามฤคนที';
      case ThaigotchiConnectionState.connecting: return 'กำลังเชื่อมต่อ';
      case ThaigotchiConnectionState.connected: return 'เชื่อมต่อแล้ว';
      case ThaigotchiConnectionState.error: return 'เกิดข้อผิดพลาด';
    }
  }
  
  String displayTextEN() {
    switch (this) {
      case ThaigotchiConnectionState.disconnected: return 'Disconnected';
      case ThaigotchiConnectionState.scanning: return 'Searching for Maruknathi';
      case ThaigotchiConnectionState.connecting: return 'Connecting';
      case ThaigotchiConnectionState.connected: return 'Connected';
      case ThaigotchiConnectionState.error: return 'Error';
    }
  }
}

class CulturalLocation {
  final String id;
  final String nameTh;
  final String nameEn;
  final String teaserTh;
  final String teaserEn;
  final double latitude;
  final double longitude;
  final double unlockRadiusMeters;
  final bool unlocked;
  
  const CulturalLocation({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.teaserTh,
    required this.teaserEn,
    required this.latitude,
    required this.longitude,
    this.unlockRadiusMeters = 50.0,
    this.unlocked = false,
  });
  
  CulturalLocation copyWith({bool? unlocked}) {
    return CulturalLocation(
      id: id,
      nameTh: nameTh,
      nameEn: nameEn,
      teaserTh: teaserTh,
      teaserEn: teaserEn,
      latitude: latitude,
      longitude: longitude,
      unlockRadiusMeters: unlockRadiusMeters,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}

/// Where the message originated from
enum MessageSource {
  voice,       // กดปุ่มอุปกรณ์พูด → อุปกรณ์ตอบเสียง
  text,        // พิมพ์ในแอป → แชทตอบ (text-only)
  unlock,      // unlock location → อุปกรณ์เล่าเรื่อง
  system,      // welcome message, etc
}

class ChatMessage {
  final String text;
  final bool isPet;
  final MessageSource source;
  final DateTime timestamp;
  final String? locationId;   // ถ้าเป็น unlock → ID วัด
  final bool spokenByDevice;  // อุปกรณ์พูดเสียงไปแล้วหรือยัง
  final String? topicId;      // ถ้าเป็น tip → topicId ของ tip (ไว้หาไฟล์เสียง)
  
  const ChatMessage({
    required this.text,
    required this.isPet,
    this.source = MessageSource.text,
    required this.timestamp,
    this.locationId,
    this.spokenByDevice = false,
    this.topicId,
  });
  
  ChatMessage copyWith({bool? spokenByDevice}) {
    return ChatMessage(
      text: text,
      isPet: isPet,
      source: source,
      timestamp: timestamp,
      locationId: locationId,
      spokenByDevice: spokenByDevice ?? this.spokenByDevice,
      topicId: topicId,
    );
  }
  
  // Serialization for persistence
  Map<String, dynamic> toJson() => {
    'text': text,
    'isPet': isPet,
    'source': source.name,
    'timestamp': timestamp.toIso8601String(),
    'locationId': locationId,
    'spokenByDevice': spokenByDevice,
    'topicId': topicId,
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] ?? '',
      isPet: json['isPet'] ?? false,
      source: MessageSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => MessageSource.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      locationId: json['locationId'],
      spokenByDevice: json['spokenByDevice'] ?? false,
      topicId: json['topicId'],
    );
  }
}

class RAGResponse {
  final String text;
  final String? audioFile;
  final double confidence;
  final String? topicId;
  
  const RAGResponse({
    required this.text,
    this.audioFile,
    this.confidence = 0.0,
    this.topicId,
  });
}