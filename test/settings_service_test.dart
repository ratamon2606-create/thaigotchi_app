import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaigotchi/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings support Thai and English', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = SettingsService();
    await settings.init();

    expect(settings.language, 'th');
    expect(settings.t('app_name'), 'มฤคนที');

    await settings.setLanguage('en');

    expect(settings.language, 'en');
    expect(settings.languageCode, 'en-US');
    expect(settings.t('app_name'), 'Maruknathi');
  });
}
