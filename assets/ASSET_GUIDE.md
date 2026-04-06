# Mint Asset Generation Guide

## 🎨 Assets Created

The following SVG assets have been created in the `assets/` folder:

### 1. Launcher Icon
- **File:** `assets/icon/mint_logo.svg`
- **Size:** 512x512 (scalable)
- **Design:** Emerald Green (#2ECC71) circular icon with mint leaf + lightning bolt fusion

### 2. Splash Screen
- **File:** `assets/images/splash_screen.svg`
- **Size:** 1080x1920 (full HD portrait)
- **Design:** Light mint background with centered logo and "MINT" branding

## 📋 How to Generate PNG Files

### Option A: Using the HTML Preview (Recommended)

1. Open `assets/generate_assets.html` in a web browser (Chrome/Edge)
2. Right-click on each preview image
3. Select "Save Image As..."
4. Save as:
   - Launcher Icon → `assets/icon/mint_logo.png` (512x512)
   - Splash Screen → `assets/images/splash.png` (1080x1920)

### Option B: Using Online Converter

1. Visit: https://cloudconvert.com/svg-to-png
2. Upload the SVG files
3. Set dimensions (512x512 for icon, 1080x1920 for splash)
4. Download and place in respective folders

### Option C: Using Inkscape (Free Desktop App)

1. Download: https://inkscape.org
2. Open the SVG file
3. File → Export PNG Image
4. Set dimensions and export

## ⚙️ Flutter Configuration

### 1. Update pubspec.yaml (Already configured)

The following is already set up in your `pubspec.yaml`:

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon/mint_logo.png"
  adaptive_icon_background: "#2ECC71"
  adaptive_icon_foreground: "assets/icon/mint_foreground.png"
```

### 2. Generate App Icons

After creating the PNG files, run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### 3. Android Native Splash Screen

For Android, add the native splash configuration:

```bash
flutter pub add flutter_native_splash
```

Then create `flutter_native_splash.yaml`:

```yaml
flutter_native_splash:
  color: "#F0F9F4"
  image: assets/images/splash.png
  android: true
  ios: true
  web: false
```

Run:
```bash
flutter pub run flutter_native_splash:create
```

## 🎨 Design Specifications

### Color Palette
| Color | Hex Code | Usage |
|-------|----------|-------|
| Emerald Green | `#2ECC71` | Primary brand, bolt, text |
| Dark Mint | `#27AE60` | Accents, hover states |
| Light Mint | `#F0F9F4` | Splash background |
| Soft White | `#FFFFFF` | Icon background, leaf |
| Slate Gray | `#95A5A6` | Subtitle text |
| Light Gray | `#BDC3C7` | Tagline text |

### Typography
- **Font:** Google Fonts Poppins
- **MINT:** Bold (700), 72px, Emerald Green
- **Ledger & Sync:** Regular (400), 24px, Slate Gray
- **Tagline:** Light (300), 16px, Light Gray

## 📱 Adaptive Icon Layers (Android 8.0+)

For the best Huawei Y5 experience, create:

1. **Background Layer** (`mint_background.png`): Solid #2ECC71 circle
2. **Foreground Layer** (`mint_foreground.png`): White leaf + bolt on transparent

Place both in `assets/icon/` and update pubspec.yaml accordingly.

## ✅ Verification Checklist

- [ ] PNG files created in correct folders
- [ ] `flutter pub get` runs successfully
- [ ] `flutter_launcher_icons` generates icons
- [ ] App builds without asset errors
- [ ] Icon displays correctly on device
- [ ] Splash screen shows on app launch
