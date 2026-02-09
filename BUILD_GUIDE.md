# Build and Deployment Guide

This guide provides detailed instructions for building and deploying the **Clock** app (Content Filter VPN).

## Prerequisites

### Required Software
1. **Flutter SDK** (version 3.10.4 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH

2. **Android Studio** or **Android SDK Command-line Tools**
   - Download from: https://developer.android.com/studio
   - Install Android SDK Platform 21 or higher
   - Install Android SDK Build-Tools

3. **Java Development Kit (JDK)**
   - JDK 11 or higher recommended
   - Can be installed via Android Studio

### Optional Tools
- **VS Code** with Flutter extension
- **Android Emulator** (though physical device recommended for VPN testing)

## Environment Setup

### 1. Verify Flutter Installation
```bash
flutter doctor
```

This command checks your environment and displays a report. Resolve any issues marked with [✗].

### 2. Accept Android Licenses
```bash
flutter doctor --android-licenses
```

Accept all licenses by typing 'y' when prompted.

### 3. Configure Flutter for Android
```bash
flutter config --android-sdk /path/to/android/sdk
```

## Building the App

### Development Build (Debug)

For testing and development:

```bash
cd content_filter_vpn
flutter pub get
flutter build apk --debug
```

The debug APK will be located at:
```
build/app/outputs/flutter-apk/app-debug.apk
```

### Production Build (Release)

For distribution:

```bash
flutter build apk --release
```

The release APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Build App Bundle (For Google Play)

If you plan to publish on Google Play Store:

```bash
flutter build appbundle --release
```

The app bundle will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

## Code Signing (For Release Builds)

### 1. Generate a Keystore

```bash
keytool -genkey -v -keystore ~/clock-app-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias clock-app
```

Follow the prompts to set a password and enter your information.

### 2. Create key.properties File

Create a file at `android/key.properties`:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=clock-app
storeFile=<path-to-your-keystore>/clock-app-key.jks
```

### 3. Update build.gradle

The project's `android/app/build.gradle` should already be configured to use the keystore. If not, add:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. Build Signed APK

```bash
flutter build apk --release
```

## Installation

### Install via USB

1. Enable USB debugging on your Android device:
   - Go to Settings > About Phone
   - Tap "Build Number" 7 times to enable Developer Options
   - Go to Settings > Developer Options
   - Enable "USB Debugging"

2. Connect your device via USB

3. Install the app:
   ```bash
   flutter install
   ```

   Or manually:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

### Install via File Transfer

1. Transfer the APK to your device (email, cloud storage, etc.)
2. On your device, enable "Install from Unknown Sources"
3. Open the APK file and follow the installation prompts

## Testing

### Run in Debug Mode

```bash
flutter run
```

This will install and run the app on a connected device or emulator with hot reload enabled.

### Run Tests

```bash
flutter test
```

### Check for Issues

```bash
flutter analyze
```

## Optimization

### Reduce APK Size

Build with split APKs per ABI:

```bash
flutter build apk --split-per-abi
```

This creates separate APKs for different CPU architectures:
- `app-armeabi-v7a-release.apk` (32-bit ARM) - *This is the smallest APK size*
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

### Obfuscate Code

For additional security:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

## Troubleshooting Build Issues

### Issue: Gradle Build Failed

**Solution**: 
- Update Gradle version in `android/gradle/wrapper/gradle-wrapper.properties`
- Clear Gradle cache: `cd android && ./gradlew clean`

### Issue: Kotlin Version Mismatch

**Solution**: 
- Update Kotlin version in `android/build.gradle`:
  ```gradle
  ext.kotlin_version = '1.9.0'
  ```

### Issue: SDK Version Conflicts

**Solution**: 
- Ensure `compileSdkVersion` and `targetSdkVersion` are set correctly in `android/app/build.gradle`
- Recommended: compileSdkVersion 34, targetSdkVersion 34

### Issue: Dependency Conflicts

**Solution**: 
```bash
flutter pub cache repair
flutter clean
flutter pub get
```

## Distribution

### Option 1: Direct Distribution

Share the APK file directly with users via:
- Email
- Cloud storage (Google Drive, Dropbox)
- File sharing services
- Your own website

### Option 2: Google Play Store

1. Create a Google Play Developer account ($25 one-time fee)
2. Build an app bundle: `flutter build appbundle --release`
3. Create a new app listing in Google Play Console
4. Upload the app bundle
5. Complete store listing information
6. Submit for review

### Option 3: Alternative App Stores

Consider publishing to:
- Amazon Appstore
- Samsung Galaxy Store
- F-Droid (for open-source apps)

## Continuous Integration (Optional)

### GitHub Actions Example

Create `.github/workflows/build.yml`:

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - uses: actions/setup-java@v2
      with:
        distribution: 'zulu'
        java-version: '11'
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.4'
    
    - run: flutter pub get
    - run: flutter build apk --release
    
    - uses: actions/upload-artifact@v2
      with:
        name: release-apk
        path: build/app/outputs/flutter-apk/app-release.apk
```

## Version Management

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Format: `major.minor.patch+buildNumber`

## Post-Build Checklist

- [ ] Test on multiple Android versions (API 21+)
- [ ] Test on different screen sizes
- [ ] Verify VPN functionality
- [ ] Test device admin activation
- [ ] Verify auto-start after reboot
- [ ] Check battery usage
- [ ] Test uninstallation process
- [ ] Verify blocked domains work correctly
- [ ] Test app performance under load

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Android Developer Guide](https://developer.android.com/guide)
- [Flutter Build and Release](https://flutter.dev/docs/deployment/android)

---

**Last Updated**: December 2025
