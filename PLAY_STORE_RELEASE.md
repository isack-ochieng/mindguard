# MindGuard Play Store release setup

The Android application ID is `com.mindguard.app`.

The `mindguard-v2` branch is configured to produce a signed Android App Bundle (`.aab`) for Google Play and a signed release APK.

## GitHub Actions secrets

Add these four repository secrets before running the production release workflow:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The keystore should be an upload keystore that you retain securely. Do not commit it to Git.

Example generation command:

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

To create the Base64 secret on PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

For local release builds, place the keystore at `android/app/upload-keystore.jks` and copy `android/key.properties.example` to `android/key.properties`, replacing the placeholder values.

## Build outputs

The production workflow creates:

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

The AAB is the artifact intended for Google Play.

## Versioning

The current app version is `1.0.0+1` in `pubspec.yaml`. Increase the build number for every subsequent Play release.
