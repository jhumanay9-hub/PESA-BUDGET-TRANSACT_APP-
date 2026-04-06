# 🌿 Pesa Budget - M-PESA Transaction Tracker

> **M-PESA Ledger & Sync Engine for Huawei Y5 (Android 9/10)**

A unified Flutter application that combines background SMS monitoring, Supabase cloud sync, and local SQLite ledger into a single, cohesive M-PESA transaction tracking experience.

---

## ✨ Features

- **📱 Background SMS Service** - Automatically detects and parses M-PESA messages
- **☁️ Supabase Integration** - Cloud backup and synchronization
- **💾 SQLite Ledger** - Offline-first local database
- **🔐 Security** - PIN lock and biometric authentication
- **📊 Filter & Search** - Advanced transaction filtering by category, type, and timeframe
- **📥 Export** - Download statements as PDF or CSV
- **🎨 Modern UI** - Emerald themed Material Design 3

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions
- Android device (Huawei Y5 recommended) or emulator

### Installation

```bash
# 1. Clone and navigate to project
cd TRansact__app.n

# 2. Fetch dependencies
flutter pub get

# 3. Generate app icons (after creating PNG assets)
flutter pub run flutter_launcher_icons

# 4. Generate native splash screen (after creating PNG assets)
flutter pub run flutter_native_splash:create

# 5. Run on device
flutter run
```

---

## 🏗️ Architecture

```
lib/
├── core/                    # App-wide utilities
│   ├── constants.dart       # Supabase URLs, theme colors
│   ├── logger.dart          # Unified logging system
│   └── theme.dart           # PesaBudgetTheme configuration
├── data/                    # Data layer
│   ├── database_helper.dart # SQLite operations
│   └── session_repository.dart # SharedPreferences wrapper
├── models/                  # Data models
│   └── transaction_model.dart # Transaction entity
├── services/                # Business logic
│   ├── background_service.dart # Foreground task handler
│   ├── connectivity_service.dart # Network monitoring (Dual-Check)
│   ├── database_service.dart # DB abstraction
│   ├── overlay_service.dart # Pop-up window service
│   ├── permission_manager.dart # Android permissions
│   ├── service_initializer.dart # Boot sequence
│   ├── sms_parser.dart # M-PESA SMS regex parser
│   ├── sms_service.dart # SMS inbox listener
│   └── supabase_service.dart # Cloud sync with timeout
└── UI/                      # Presentation layer
    ├── Screens/             # Full pages
    │   ├── dashboard_screen.dart
    │   ├── security_page.dart
    │   ├── settings_page.dart
    │   └── ...
    └── Widgets/             # Reusable components
        ├── main_drawer.dart
        ├── transaction_filter_bar.dart
        └── ...
```

---

## 🔐 Boot Sequence

The app follows a strict initialization order:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // 1. Flutter bindings
  
  await SessionRepository().initialize();     // 2. Local session flags
  await Supabase.initialize();                // 3. Cloud connection
  await ServiceInitializer().initializeApp(); // 4. DB & Foreground service
  
  runApp(PesaBudgetApp());                    // 5. Launch app
}
```

---

## 🌐 Local-First Architecture

### Connectivity Strategy

Pesa Budget uses a **Dual-Check Connectivity** system to prevent false offline detection:

1. **Radio Check** - Verifies WiFi/mobile data radios are active
2. **DNS Probe** - Confirms actual internet reachability via DNS lookup

```dart
// In ConnectivityService
Future<bool> hasInternet() async {
  // 1. Check hardware interface
  final connectivityResult = await _connectivity.checkConnectivity();
  
  // 2. Active DNS probe (3-second timeout for Huawei Y5)
  final result = await InternetAddress.lookup('google.com')
      .timeout(const Duration(seconds: 3));
  
  return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
}
```

### Sync Behavior

| Scenario | Behavior |
|----------|----------|
| **Online** | Sync to Supabase immediately, mark `is_synced = true` |
| **Offline** | Save to SQLite only, retry on next connectivity |
| **Poor Network** | 15-second timeout prevents hanging, retry later |

---

## 📱 Android Configuration

### Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### Foreground Service

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundTaskService"
    android:stopWithTask="false"
    android:foregroundServiceType="specialUse" />
```

---

## 🔧 Troubleshooting

### "No such host is known" during build
- Check internet connectivity
- Ensure Maven/Google repositories are accessible

### SMS not being detected
- Grant RECEIVE_SMS and READ_SMS permissions
- Ensure M-PESA sender address is exactly "MPESA"

### App stuck in offline mode
- DNS probe may be blocked by firewall
- See `ARCHITECTURE_AUDIT.md` for multi-endpoint fallback solution

### Build fails with dependency conflicts
```bash
flutter clean
flutter pub get
flutter pub cache repair
```

---

## 📄 Architecture Audit

See [`ARCHITECTURE_AUDIT.md`](ARCHITECTURE_AUDIT.md) for detailed analysis of:
- Race conditions during registration
- DNS probe false negatives
- Thread performance on low-end devices

---

## 📦 Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK (Huawei Y5 optimized)
flutter build apk --release --split-per-abi

# App Bundle (Play Store)
flutter build appbundle --release
```

---

## 📄 License

This project is proprietary software for Pesa Budget.

---

## 🙏 Acknowledgments

- **M-PESA** - Safaricom's mobile money service
- **Supabase** - Open-source Firebase alternative
- **Flutter** - Google's UI toolkit
