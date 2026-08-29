# Thaigotchi — มฤคนที 🦌

Cultural Heritage Tamagotchi for Kasetsart University Higher Education Innovation Awards 2026.

## Project Structure

```
thaigotchi_app/
├── pubspec.yaml                    # Dependencies + assets declaration
├── README.md                       # This file
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml     # Permissions (BLE/Location/Mic)
├── assets/
│   ├── data/
│   │   ├── locations.json          # 3 Bangkok temples
│   │   └── rag_content.json        # Pre-baked Q&A pairs
│   ├── images/                     # ← Place your artwork here
│   │   ├── adopt_background.png
│   │   ├── daily_background.png
│   │   ├── chat_background.png
│   │   ├── maruknathi_in_jar.png
│   │   ├── maruknathi_searching.png
│   │   ├── chat_avatar.png
│   │   ├── nav_device.png
│   │   ├── nav_chat.png
│   │   └── nav_map.png
│   └── fonts/                      # ← Place Chulabhorn Likit fonts here
│       ├── ChulabhornLikitText-Light.otf
│       ├── ChulabhornLikitText-Regular.otf
│       ├── ChulabhornLikitText-Medium.otf
│       └── ChulabhornLikitText-Bold.otf
└── lib/
    ├── main.dart                   # App entry — initializes services
    ├── models/
    │   └── pet_state.dart          # DeviceState, ChatMessage, etc.
    ├── theme/
    │   ├── colors.dart             # App color palette
    │   └── app_theme.dart          # Material theme
    ├── services/
    │   ├── ble_service.dart        # BLE communication w/ ESP32
    │   ├── settings_service.dart   # i18n + user preferences
    │   ├── rag_service.dart        # Local RAG matching
    │   ├── voice_service.dart      # TTS + STT (phone)
    │   ├── geofencing_service.dart # Location-based unlocking
    │   ├── locations_service.dart  # Temple data loader
    │   └── chat_history_service.dart # Persistent chat log
    └── screens/
        ├── adopt_screen.dart       # Onboarding / pet adoption
        ├── searching_screen.dart   # BLE device scan
        ├── main_navigation.dart    # Bottom nav (3 tabs)
        ├── daily_screen.dart       # Tab 1: Device status
        ├── chat_screen.dart        # Tab 2: Conversation log
        ├── map_screen.dart         # Tab 3: Temple map
        └── settings_screen.dart    # Settings page
```

## Setup

### 1. Install Flutter

```bash
# Ensure Flutter ≥ 3.4.0
flutter --version
```

### 2. Get Dependencies

```bash
cd thaigotchi_app
flutter pub get
```

### 3. Add Assets

Place your artwork files in `assets/images/` using exact filenames listed in the structure above.

Place Chulabhorn Likit font files in `assets/fonts/`.

### 4. Run

```bash
flutter run
```

## Architecture

### Services (Singleton Pattern)
All services are accessible globally:
```dart
final ble = BLEService();
final settings = SettingsService();
final rag = LocalRAGService();
// etc.
```

### Chat Message Flow

```
┌─────────────────────────────────────────┐
│  USER INPUT                              │
├─────────────────────────────────────────┤
│  Voice (button hold)  → MessageSource.voice
│  Text typed in app    → MessageSource.text
│  Geofence unlock      → MessageSource.unlock
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  LOCAL RAG MATCHING                      │
│  • Keyword scoring                       │
│  • Context-aware (location boost)        │
│  • Falls back to default responses       │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  RESPONSE HANDLING                       │
├─────────────────────────────────────────┤
│  Voice source  → ESP32 plays audio       │
│  Text source   → Text-only (user can tap │
│                  "Play via device"        │
│                  button to speak later)  │
│  Unlock source → ESP32 plays WAV from SD │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  CHAT HISTORY (Persistent)               │
│  Last 200 messages saved across sessions │
└─────────────────────────────────────────┘
```

### Button Events from ESP32

| Event | Trigger | App Behavior |
|-------|---------|--------------|
| `short` | Single tap (<500ms) | (Device toggles power) |
| `hold_start` | Hold > 500ms | App starts STT listening |
| `hold_end` | Release button | App stops STT, processes question |

### BLE Commands to ESP32

| Command | Format | Purpose |
|---------|--------|---------|
| `pose:idle` | `pose:<name>` | Change OLED animation |
| `play:welcome` | `play:<filename>` | Play WAV from SD card |
| `say:text` | `say:<text>` | TTS via phone (future: stream) |
| `unlock:wat_pho` | `unlock:<id>` | Notify location unlock |

## Data Files

### `assets/data/locations.json`
3 Bangkok temples with coordinates, names (TH/EN), and unlock radius.

### `assets/data/rag_content.json`
- 11 main topics across 3 temples
- Greetings (TH/EN)
- Fallback responses
- Keyword matching arrays for each topic

To add more Q&A pairs, edit `rag_content.json` topics array.

## Features

### Internationalization (TH/EN)
Toggle in Settings or top-left of Adopt screen.
All UI strings, locations, and RAG content support both languages.

### Voice Pipeline
- Phone STT (`speech_to_text`) → text
- Local RAG → answer text
- Phone TTS (`flutter_tts`) → speaker
- (Future: stream audio bytes to ESP32 via BLE)

### Geofencing
- Phone GPS tracked continuously
- Auto-unlock when entering location radius (default 80m)
- Distance shown in map

### Persistence
- `petName`, `language`, `audioVolume` etc. in `shared_preferences`
- `unlocked_locations` set in `shared_preferences`
- `chat_history_v1` list (max 200) in `shared_preferences`

## Color Palette

| Use | Hex | Name |
|-----|-----|------|
| Adopt/Searching bg | `#F5F3E8` | River Cream |
| Mint accent | `#D8E8DD` | Water Mint |
| Primary green | `#5B9B7E` | Leaf Green |
| Lotus pink | `#F4886B` | Lotus Pink |
| Daily/Chat bg | `#F5EBD8` | Cafe Cream |
| Cafe wall | `#A87F5C` | Cafe Wall Brown |
| Accent red | `#8B3A3A` | Cafe Brick Red |
| Deep brown | `#5C3A24` | Cafe Deep Brown |

## Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# Install on connected device
flutter install
```

## Troubleshooting

### BLE not connecting
- Check Bluetooth permission granted
- Check Location permission granted (required for BLE scan on Android)
- Verify ESP32 device name is exactly `Thaigotchi-Maru`

### TTS not speaking
- Check device language settings (Thai TTS engine installed)
- On Android: Settings → Languages → Text-to-speech → Thai
- On iOS: Settings → Accessibility → Spoken Content → Voices → Thai

### Microphone not working
- Check `RECORD_AUDIO` permission in AndroidManifest
- Run `flutter clean && flutter pub get`

### Images not loading
- Verify exact filename (case-sensitive on real devices)
- Verify `pubspec.yaml` has `- assets/images/` declared
- Run `flutter clean` after adding new images

## License

Educational project — Kasetsart University.

## Contact

Built for Higher Education Innovation Awards 2026.