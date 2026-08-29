import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';
import 'adopt_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ble = BLEService();
  final _settings = SettingsService();
  final _voice = VoiceService();
  final _history = ChatHistoryService();

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
      backgroundColor: AppColors.cafeCream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Language toggle (top - prominent)
                  _buildLanguageToggle(),
                  
                  const SizedBox(height: 20),
                  
                  // Privacy section
                  _buildSection(
                    title: _settings.t('settings_privacy'),
                    children: [
                      _SettingsTile(
                        icon: Icons.share_outlined,
                        title: _settings.t('settings_share_data'),
                        subtitle: _settings.t('settings_share_data_desc'),
                        trailing: Switch(
                          value: _settings.shareData,
                          onChanged: (v) => _settings.setShareData(v),
                          activeColor: AppColors.leafGreen,
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.delete_outline,
                        title: _settings.t('settings_clear'),
                        iconColor: AppColors.error,
                        onTap: () => _confirmClearHistory(),
                      ),
                    ],
                  ),
                  
                  // Device section
                  _buildSection(
                    title: _settings.t('settings_device'),
                    children: [
                      _SettingsTile(
                        icon: Icons.edit_outlined,
                        title: _settings.t('settings_rename'),
                        subtitle: _settings.petName,
                        onTap: () => _showRenameDialog(),
                      ),
                      _SettingsTile(
                        icon: Icons.bluetooth,
                        title: _settings.t('settings_ble'),
                        subtitle: _ble.isConnected
                            ? _ble.deviceId
                            : (_settings.isThai 
                                ? 'ไม่ได้เชื่อมต่อ' 
                                : 'Not connected'),
                        trailing: Icon(
                          _ble.isConnected
                              ? Icons.check_circle
                              : Icons.chevron_right,
                          color: _ble.isConnected
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        onTap: () => _showBLEManagement(),
                      ),
                      _SettingsTile(
                        icon: Icons.volume_up_outlined,
                        title: _settings.t('settings_audio'),
                        subtitle: _settings.t('settings_audio_desc'),
                        onTap: () => _showAudioSettings(),
                      ),
                    ],
                  ),
                  
                  // About section
                  _buildSection(
                    title: _settings.t('settings_about'),
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: _settings.t('settings_version'),
                        subtitle: '0.1.0+1',
                      ),
                      _SettingsTile(
                        icon: Icons.school_outlined,
                        title: _settings.t('settings_university'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reset
                  OutlinedButton(
                    onPressed: () => _confirmReset(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _settings.t('settings_reset'),
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      padding: const EdgeInsets.all(8),
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
          _buildLangButton('th', _settings.t('thai')),
          _buildLangButton('en', _settings.t('english')),
        ],
      ),
    );
  }

  Widget _buildLangButton(String lang, String label) {
    final isActive = _settings.language == lang;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await _settings.setLanguage(lang);
          await _voice.setLanguage(_settings.languageCode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive 
                ? AppColors.leafGreen 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ChulabhornLikit',
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive 
                  ? AppColors.white 
                  : AppColors.cafeWallBrown,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.cafeDeepBrown,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _settings.t('settings_title'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.cafeDeepBrown,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'ChulabhornLikit',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.cafeWallBrown,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _settings.petName);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_settings.t('settings_rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_settings.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              String newName = controller.text.trim();
              if (newName.isEmpty) newName = 'มฤคนที';
              await _settings.setPetName(newName);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(_settings.t('confirm')),
          ),
        ],
      ),
    );
  }

  void _showAudioSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _settings.isThai ? 'ความดังเสียง' : 'Volume',
                style: const TextStyle(
                  fontFamily: 'ChulabhornLikit',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setSt) => Slider(
                  value: _settings.audioVolume,
                  onChanged: (v) {
                    setSt(() {});
                    _settings.setAudioVolume(v);
                  },
                  activeColor: AppColors.leafGreen,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBLEManagement() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _settings.t('settings_ble'),
                style: const TextStyle(
                  fontFamily: 'ChulabhornLikit',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _ble.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: _ble.isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _ble.isConnected
                          ? _ble.deviceId
                          : (_settings.isThai 
                              ? 'ไม่ได้เชื่อมต่อ' 
                              : 'Not connected'),
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_ble.isConnected)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _ble.disconnect();
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: Text(_settings.isThai 
                        ? 'ตัดการเชื่อมต่อ' 
                        : 'Disconnect'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _ble.startScan();
                    },
                    child: Text(_settings.isThai 
                        ? 'เชื่อมต่อใหม่' 
                        : 'Reconnect'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 48, color: AppColors.cafeWallBrown),
            const SizedBox(height: 16),
            Text(
              _settings.isThai 
                  ? 'ยังไม่มีประวัติการถาม' 
                  : 'No question history yet',
              style: const TextStyle(
                fontFamily: 'ChulabhornLikit',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_settings.t('settings_clear')),
        content: Text(
          _settings.isThai 
              ? 'ประวัติการสนทนาจะถูกลบทั้งหมด\nและไม่สามารถกู้คืนได้'
              : 'All chat history will be deleted permanently',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_settings.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await _history.clear();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_settings.isThai 
                        ? 'ลบประวัติแล้ว' 
                        : 'History cleared'),
                  ),
                );
              }
            },
            child: Text(
              _settings.t('delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_settings.t('settings_reset')),
        content: Text(
          _settings.isThai
              ? 'จะลบข้อมูลทั้งหมดและกลับไปหน้ารับเลี้ยง\n'
                'การกระทำนี้ไม่สามารถยกเลิกได้'
              : 'All data will be cleared and you\'ll go back to adopt screen.\n'
                'This cannot be undone',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_settings.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await _settings.clearAll();
              await _history.clear();
              await _ble.disconnect();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AdoptScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: Text(
              _settings.t('settings_reset'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.cafeWallBrown).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.cafeWallBrown,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'ChulabhornLikit',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: iconColor ?? AppColors.cafeDeepBrown,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'ChulabhornLikit',
                        fontSize: 12,
                        color: AppColors.cafeWallBrown,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}