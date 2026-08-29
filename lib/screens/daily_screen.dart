import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import '../widgets/connection_banner.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  final _ble = BLEService();
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onUpdate);
    _settings.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _ble.removeListener(_onUpdate);
    _settings.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image (contains pet + jar + cafe scene)
          Positioned.fill(
            child: Image.asset(
              'assets/images/daily_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.cafeBg,
                  ),
                );
              },
            ),
          ),

          // Cream gradient at bottom to blend status cards
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.cafeCream.withValues(alpha: 0.6),
                    AppColors.cafeCream.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.55, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const ConnectionBanner(),
                _buildHeader(),
                const Spacer(),
                _buildStatusCards(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/header_daily.png',
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cafeBrickRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_settings.petName,
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
              icon: const Icon(
                Icons.settings,
                color: AppColors.cardWhite,
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildStatusCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          _StatusCard(
            icon: Icons.bluetooth_connected,
            label: _settings.t('connection_label'),
            value: _ble.isConnected
                ? (_ble.deviceId.isEmpty ? 'Maruknathi-001' : _ble.deviceId)
                : (_settings.isThai ? 'ไม่ได้เชื่อมต่อ' : 'Disconnected'),
            color: _ble.isConnected
                ? AppColors.bleConnected
                : AppColors.bleDisconnected,
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          _StatusCard(
            icon: _getBatteryIcon(),
            label: _settings.t('battery_label'),
            value: '${_ble.batteryLevel}%',
            color: _getBatteryColor(),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          _StatusCard(
            icon: Icons.location_on,
            label: _settings.t('location_label'),
            value: _getLocationText(),
            color: AppColors.cafeBrickRed,
          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_ble.batteryLevel > 80) return Icons.battery_full;
    if (_ble.batteryLevel > 50) return Icons.battery_5_bar;
    if (_ble.batteryLevel > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor() {
    if (_ble.batteryLevel > 50) return AppColors.success;
    if (_ble.batteryLevel > 20) return AppColors.warning;
    return AppColors.error;
  }

  String _getLocationText() {
    if (!_ble.gpsData.fixed) {
      return _settings.isThai ? 'กำลังค้นหา...' : 'Searching...';
    }
    return _settings.isThai ? 'พบตำแหน่งแล้ว' : 'Location found';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'ChulabhornLikit',
                    fontSize: 12,
                    color: AppColors.cafeWallBrown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'ChulabhornLikit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cafeDeepBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}