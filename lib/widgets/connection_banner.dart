import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';

/// A slim banner shown at the top of a screen when the device
/// is not connected via BLE. Auto-hides when connected.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  final _ble = BLEService();
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _ble.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Connected → nothing to show
    if (_ble.isConnected) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.cafeBrickRed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            color: AppColors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _settings.isThai
                ? 'ไม่ได้เชื่อมต่อกับอุปกรณ์'
                : 'Connection lost',
            style: const TextStyle(
              fontFamily: 'ChulabhornLikit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
