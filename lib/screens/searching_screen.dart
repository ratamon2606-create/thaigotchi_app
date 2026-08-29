import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../models/pet_state.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import '../widgets/png_animation.dart';
import 'main_navigation.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  final _ble = BLEService();
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBLEStateChanged);
    _startScanning();
  }

  Future<void> _startScanning() async {
    await _ble.startScan();
  }

  void _onBLEStateChanged() {
    if (_ble.connectionState == ThaigotchiConnectionState.connected) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
        });
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ble.removeListener(_onBLEStateChanged);
    super.dispose();
  }

  void _retry() {
    _ble.startScan();
  }

  // @override
  // Widget build(BuildContext context) {
  //   // 1. Get the screen dimensions to make sizing dynamic
  //   final screenSize = MediaQuery.sizeOf(context);
    
  //   // 2. Set animation size relative to screen width (e.g., 75% of screen width)
  //   // We use clamp to ensure it doesn't get too massive on tablets
  //   final double animationSize = (screenSize.width * 0.75).clamp(200.0, 500.0);

  //   return Scaffold(
  //     backgroundColor: AppColors.riverCream,
  //     body: Stack(
  //       // 3. Ensure the stack forces its children to fill the entire screen
  //       fit: StackFit.expand,
  //       children: [
  //         // Background Layer
  //         Container(
  //           width: double.infinity,
  //           height: double.infinity,
  //           decoration: const BoxDecoration(
  //             gradient: AppColors.riverLotusBg,
  //           ),
  //         ),
          
  //         // Content Layer
  //         AnimatedBuilder(
  //           animation: _ble,
  //           builder: (context, _) => _buildContent(animationSize),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final double animationSize = (screenSize.width * 0.75).clamp(200.0, 500.0);

    return Scaffold(
      // You can remove the backgroundColor here since the Container covers it
      body: Stack(
        fit: StackFit.expand,
        children: [
          
          // ─── Custom Background Gradient ───
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDCCAB2), // Your chosen base color
                  Color.fromARGB(255, 175, 146, 109), // A darker shade of the base color for the bottom
                ],
                // The stops determine where the color transitions happen. 
                // 0.5 means the top half is mostly the solid base color, 
                // and it starts getting darker towards the bottom half.
                stops: [0.5, 1.0], 
              ),
            ),
          ),
          
          // Content Layer
          AnimatedBuilder(
            animation: _ble,
            builder: (context, _) => _buildContent(animationSize),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double animSize) {
    bool isError = _ble.connectionState == 
        ThaigotchiConnectionState.disconnected ||
        _ble.connectionState == ThaigotchiConnectionState.error;
    bool isScanning = _ble.connectionState == 
        ThaigotchiConnectionState.scanning;
    bool isConnected = _ble.connectionState == 
        ThaigotchiConnectionState.connected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── Searching animation (Responsive Size) ───
            SizedBox(
              width: animSize,
              height: animSize,
              child: isScanning
                  ? PngAnimation(
                      frames: List.generate(
                        11,
                        (i) => 'assets/images/searching/frame_${(i + 1).toString().padLeft(2, '0')}.png',
                      ),
                      frameRate: 12,
                      // Pass dynamic size to your custom animation widget
                      size: animSize, 
                    )
                  : Center(
                      child: Image.asset(
                        'assets/images/searching/frame_01.png',
                        width: animSize,
                        height: animSize,
                        // 4. Add BoxFit to properly scale your 1080x1080 images
                        fit: BoxFit.contain, 
                        errorBuilder: (_, __, ___) => Container(
                          width: animSize * 0.75, // Scale fallback circle accordingly
                          height: animSize * 0.75,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.waterMint,
                          ),
                          child: Icon(
                            Icons.pets,
                            size: animSize * 0.3, // Scale icon accordingly
                            color: AppColors.leafDark,
                          ),
                        ),
                      ),
                    ),
            ),
            
            const SizedBox(height: 40),
            
            Text(
              _getStatusTitle(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.cafeDeepBrown,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms),
            
            const SizedBox(height: 12),
            
            Text(
              _getStatusMessage(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color.fromARGB(255, 112, 79, 50),
                  ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            
            const SizedBox(height: 40),
            
            if (isError)
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: Text(_settings.t('retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.leafGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
              ).animate().fadeIn(),
            
            if (isConnected)
              const Icon(
                Icons.check_circle,
                size: 60,
                color: AppColors.leafGreen,
              ).animate().scale(
                begin: const Offset(0, 0),
                curve: Curves.elasticOut,
              ),
          ],
        ),
      ),
    );
  }

  // ... _getStatusTitle and _getStatusMessage remain exactly the same ...
  String _getStatusTitle() {
    switch (_ble.connectionState) {
      case ThaigotchiConnectionState.scanning:
        return _settings.isThai
            ? 'กำลังค้นหา${_settings.petName}'
            : 'Searching for ${_settings.petName}';
      case ThaigotchiConnectionState.connecting:
        return _settings.t('connecting');
      case ThaigotchiConnectionState.connected:
        return _settings.isThai
            ? 'เจอ${_settings.petName}แล้ว!'
            : 'Found ${_settings.petName}!';
      default:
        return _settings.isThai ? 'หาไม่พบ' : 'Not found';
    }
  }

  String _getStatusMessage() {
    switch (_ble.connectionState) {
      case ThaigotchiConnectionState.scanning:
        return _settings.t('searching_subtitle');
      case ThaigotchiConnectionState.connecting:
        return _settings.isThai
            ? 'เชื่อมต่อกับมฤคนทีของคุณ'
            : 'Connecting to your Maruknathi';
      case ThaigotchiConnectionState.connected:
        return _settings.isThai ? 'ยินดีต้อนรับกลับมา ✨' : 'Welcome back ✨';
      default:
        return _settings.isThai
            ? 'ตรวจสอบว่าอุปกรณ์เปิดอยู่\nและบลูทูธของโทรศัพท์เปิดอยู่'
            : 'Check that the device is on\nand Bluetooth is enabled';
    }
  }
}