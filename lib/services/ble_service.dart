import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pet_state.dart';

class BLEConfig {
  static const String SERVICE_UUID = 
      "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHAR_DEVICE_STATE = 
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String CHAR_GPS = 
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String CHAR_BATTERY = 
      "beb5483e-36e1-4688-b7f5-ea07361b26aa";
  static const String CHAR_COMMAND = 
      "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String CHAR_BUTTON_EVENT = 
      "beb5483e-36e1-4688-b7f5-ea07361b26ac";
  
  static const String DEVICE_NAME = "Thaigotchi-Maru";
}

/// Button event types from device
enum ButtonEvent {
  none,
  shortPress,    // toggle power on/off
  holdStart,     // mic ON (start recording)
  holdEnd,       // mic OFF (stop + process)
}

class BLEService extends ChangeNotifier {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();
  
  BluetoothDevice? _device;
  BluetoothCharacteristic? _deviceStateChar;
  BluetoothCharacteristic? _gpsChar;
  BluetoothCharacteristic? _batteryChar;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _buttonEventChar;
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  
  ThaigotchiConnectionState _connectionState = 
      ThaigotchiConnectionState.disconnected;
  DeviceState _deviceState = const DeviceState();
  GPSData _gpsData = const GPSData();
  int _batteryLevel = 100;
  String _deviceId = '';
  
  // Button event stream
  final _buttonEventController = 
      StreamController<ButtonEvent>.broadcast();
  Stream<ButtonEvent> get buttonEvents => _buttonEventController.stream;
  
  ThaigotchiConnectionState get connectionState => _connectionState;
  DeviceState get deviceState => _deviceState;
  GPSData get gpsData => _gpsData;
  int get batteryLevel => _batteryLevel;
  String get deviceId => _deviceId;
  bool get isConnected => 
      _connectionState == ThaigotchiConnectionState.connected;
  
  // ============ PERMISSIONS ============
  Future<bool> requestPermissions(BuildContext context) async {
    debugPrint('🔐 Requesting permissions...');
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.microphone,
    ].request();
    
    bool allGranted = statuses.values.every((s) => s.isGranted);
    
    if (!allGranted) {
      debugPrint('❌ Some permissions denied');
      return false;
    }
    
    return true;
  }
  
  // ============ SCAN ============
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    debugPrint('🔍 Scanning for ${BLEConfig.DEVICE_NAME}...');
    _updateConnectionState(ThaigotchiConnectionState.scanning);
    
    try {
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateConnectionState(ThaigotchiConnectionState.error);
        return;
      }
    } catch (e) {
      debugPrint('Adapter check: $e');
    }
    
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (ScanResult r in results) {
            if (r.device.platformName == BLEConfig.DEVICE_NAME) {
              debugPrint('✅ Found! RSSI: ${r.rssi}');
              _device = r.device;
              _deviceId = 'Maruknathi-${r.device.remoteId.str.substring(0, 4)}';
              FlutterBluePlus.stopScan();
              _scanSubscription?.cancel();
              connect();
              break;
            }
          }
        },
        onError: (error) {
          _updateConnectionState(ThaigotchiConnectionState.error);
        },
      );
      
      Future.delayed(timeout, () {
        if (_connectionState == ThaigotchiConnectionState.scanning) {
          _scanSubscription?.cancel();
          _updateConnectionState(ThaigotchiConnectionState.disconnected);
        }
      });
    } catch (e) {
      debugPrint('Scan failed: $e');
      _updateConnectionState(ThaigotchiConnectionState.error);
    }
  }
  
  // ============ CONNECT ============
  Future<void> connect() async {
    if (_device == null) return;
    
    _updateConnectionState(ThaigotchiConnectionState.connecting);
    
    try {
      await _device!.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      
      _connectionSubscription = 
          _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });
      
      List<BluetoothService> services = 
          await _device!.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == 
            BLEConfig.SERVICE_UUID.toLowerCase()) {
          
          for (BluetoothCharacteristic c in service.characteristics) {
            String uuid = c.uuid.toString().toLowerCase();
            
            if (uuid == BLEConfig.CHAR_DEVICE_STATE.toLowerCase()) {
              _deviceStateChar = c;
              await _subscribeToDeviceState();
            }
            else if (uuid == BLEConfig.CHAR_GPS.toLowerCase()) {
              _gpsChar = c;
              await _subscribeToGPS();
            }
            else if (uuid == BLEConfig.CHAR_BATTERY.toLowerCase()) {
              _batteryChar = c;
              await _subscribeToBattery();
            }
            else if (uuid == BLEConfig.CHAR_COMMAND.toLowerCase()) {
              _commandChar = c;
            }
            else if (uuid == BLEConfig.CHAR_BUTTON_EVENT.toLowerCase()) {
              _buttonEventChar = c;
              await _subscribeToButton();
            }
          }
          break;
        }
      }
      
      _updateConnectionState(ThaigotchiConnectionState.connected);
      debugPrint('🦌 มฤคนที พร้อมแล้ว!');
    } catch (e) {
      debugPrint('❌ Connect failed: $e');
      _updateConnectionState(ThaigotchiConnectionState.error);
    }
  }
  
  Future<void> _subscribeToDeviceState() async {
    if (_deviceStateChar == null) return;
    await _deviceStateChar!.setNotifyValue(true);
    _deviceStateChar!.lastValueStream.listen((value) {
      try {
        String json = utf8.decode(value);
        Map<String, dynamic> data = jsonDecode(json);
        _deviceState = DeviceState.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('Device state parse: $e');
      }
    });
  }
  
  Future<void> _subscribeToGPS() async {
    if (_gpsChar == null) return;
    await _gpsChar!.setNotifyValue(true);
    _gpsChar!.lastValueStream.listen((value) {
      try {
        String json = utf8.decode(value);
        Map<String, dynamic> data = jsonDecode(json);
        _gpsData = GPSData.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('GPS parse: $e');
      }
    });
  }
  
  Future<void> _subscribeToBattery() async {
    if (_batteryChar == null) return;
    await _batteryChar!.setNotifyValue(true);
    _batteryChar!.lastValueStream.listen((value) {
      try {
        String str = utf8.decode(value);
        _batteryLevel = int.tryParse(str) ?? _batteryLevel;
        notifyListeners();
      } catch (e) {
        debugPrint('Battery parse: $e');
      }
    });
  }
  
  /// Listen for button events from device
  Future<void> _subscribeToButton() async {
    if (_buttonEventChar == null) return;
    await _buttonEventChar!.setNotifyValue(true);
    _buttonEventChar!.lastValueStream.listen((value) {
      try {
        if (value.isEmpty) return;
        String event = utf8.decode(value).trim();
        
        ButtonEvent buttonEvent = ButtonEvent.none;
        switch (event) {
          case 'short':      buttonEvent = ButtonEvent.shortPress; break;
          case 'hold_start': buttonEvent = ButtonEvent.holdStart; break;
          case 'hold_end':   buttonEvent = ButtonEvent.holdEnd; break;
        }
        
        if (buttonEvent != ButtonEvent.none) {
          debugPrint('🎮 Button: $event');
          _buttonEventController.add(buttonEvent);
        }
      } catch (e) {
        debugPrint('Button event parse: $e');
      }
    });
  }
  
  // ============ COMMANDS ============
  Future<bool> _sendCommand(String command) async {
    if (_commandChar == null) return false;
    
    try {
      List<int> bytes = utf8.encode(command);
      await _commandChar!.write(bytes);
      debugPrint('📤 Sent: $command');
      return true;
    } catch (e) {
      debugPrint('Send failed: $e');
      return false;
    }
  }
  
  /// Set pet pose on OLED
  Future<bool> setPose(String pose) => _sendCommand("pose:$pose");
  
  /// Tell device to speak text (will use TTS audio sent via BLE)
  Future<bool> speak(String text) => _sendCommand("say:$text");
  
  /// Tell device to play stored audio file
  Future<bool> playAudio(String filename) => _sendCommand("play:$filename");
  
  /// Tell device to start listening (record mic)
  Future<bool> startListening() => _sendCommand("listen:start");
  
  /// Tell device to stop listening
  Future<bool> stopListening() => _sendCommand("listen:stop");
  
  /// Notify device that a location was unlocked
  Future<bool> notifyUnlock(String locationId) => 
      _sendCommand("unlock:$locationId");
  
  // ============ DISCONNECT ============
  Future<void> disconnect() async {
    await _device?.disconnect();
    _onDisconnected();
  }
  
  void _onDisconnected() {
    _device = null;
    _deviceStateChar = null;
    _gpsChar = null;
    _batteryChar = null;
    _commandChar = null;
    _buttonEventChar = null;
    
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    _updateConnectionState(ThaigotchiConnectionState.disconnected);
  }
  
  void _updateConnectionState(ThaigotchiConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _buttonEventController.close();
    disconnect();
    super.dispose();
  }
}