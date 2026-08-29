import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import 'searching_screen.dart';

class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key});

  @override
  State<AdoptScreen> createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  final _nameController = TextEditingController();
  final _ble = BLEService();
  final _settings = SettingsService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _settings.petName;
    _settings.addListener(_onSettingsUpdate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _settings.removeListener(_onSettingsUpdate);
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _onAdoptTap() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    String petName = _nameController.text.trim();
    if (petName.isEmpty) petName = 'มฤคนที';
    await _settings.setPetName(petName);
    
    bool granted = await _ble.requestPermissions(context);
    if (!granted) {
      setState(() => _isProcessing = false);
      if (mounted) _showPermissionDialog();
      return;
    }
    
    await _settings.setHasAdoptedPet(true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SearchingScreen()),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_settings.isThai 
            ? 'ต้องการสิทธิ์' 
            : 'Permissions required'),
        content: Text(
          _settings.isThai
              ? 'Thaigotchi ต้องการสิทธิ์ Bluetooth, ตำแหน่ง และไมค์\n'
                'เพื่อค้นหาและสนทนากับมฤคนทีของคุณ'
              : 'Thaigotchi needs Bluetooth, Location, and Microphone\n'
                'to find and chat with your Maruknathi',
        ),
        actions: [
          TextButton(
            child: Text(_settings.t('cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text(_settings.t('retry')),
            onPressed: () {
              Navigator.pop(ctx);
              _onAdoptTap();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background artwork
          Positioned.fill(
            child: Image.asset(
              'assets/images/adopt_background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.riverLotusBg,
                  ),
                );
              },
            ),
          ),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.riverCream.withValues(alpha: 0.3),
                    AppColors.riverCream.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Language switcher (top-left)
                      GestureDetector(
                        onTap: () async => await _settings.toggleLanguage(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language,
                                size: 16,
                                color: AppColors.cafeWallBrown,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _settings.language.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'ChulabhornLikit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.cafeDeepBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Pet description
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _settings.isThai 
                                ? 'มฤคนที (น.)' 
                                : 'Maruknathi (n.)',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.cafeDeepBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _settings.t('pet_description'),
                            textAlign: TextAlign.right,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.cafeWallBrown,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 300.ms),
                
                const Spacer(),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          maxLength: 20,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.cafeDeepBrown,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'มฤคนที',
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        _settings.t('pet_name_label'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.cafeWallBrown),
                      ),
                    ],
                  ),
                ).animate()
                  .fadeIn(duration: 800.ms, delay: 500.ms)
                  .slideY(begin: 0.2, end: 0),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _onAdoptTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.leafGreen,
                        foregroundColor: AppColors.white,
                        elevation: 8,
                        shadowColor: AppColors.leafGreen.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _settings.t('adopt_button'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontSize: 20,
                                    letterSpacing: 2,
                                  ),
                            ),
                    ),
                  ),
                ).animate()
                  .fadeIn(duration: 800.ms, delay: 700.ms)
                  .slideY(begin: 0.3, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}