import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/settings_service.dart';
import 'daily_screen.dart';
import 'chat_screen.dart';
import 'map_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _settings = SettingsService();

  final List<Widget> _screens = const [
    DailyScreen(),
    ChatScreen(),
    MapScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _settings.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cafeCream,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                label: _settings.t('tab_device'),
                index: 0,
                fallbackIcon: Icons.devices,
              ),
              _buildNavItem(
                label: _settings.t('tab_chat'),
                index: 1,
                fallbackIcon: Icons.chat_bubble_outline,
              ),
              _buildNavItem(
                label: _settings.t('tab_map'),
                index: 2,
                fallbackIcon: Icons.map_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String label,
    required int index,
    required IconData fallbackIcon,
  }) {
    final isActive = _currentIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.cafeAccent.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full image — always full color (no grey)
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                'assets/images/nav_${_getIconName(index)}.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    fallbackIcon,
                    color: AppColors.cafeDeepBrown,
                    size: 28,
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ChulabhornLikit',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.cafeDeepBrown
                    : AppColors.cafeWallBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIconName(int index) {
    switch (index) {
      case 0: return 'device';
      case 1: return 'chat';
      case 2: return 'map';
      default: return 'device';
    }
  }
}