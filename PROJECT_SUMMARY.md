# MindGuard - Project Summary

## Overview

MindGuard is a Flutter + native Android demo for lightweight domain filtering.

The current architecture deliberately keeps the network path small:

1. Flutter presents the disguised clock UI and the protection dashboard.
2. Android VpnService captures only DNS traffic addressed to MindGuard's private DNS endpoint.
3. A local decision engine checks the requested domain against local allow/block policy.
4. Blocked domains receive a local NXDOMAIN response.
5. Allowed/unknown DNS queries are forwarded through a protected DNS socket so normal browsing continues.
6. No TLS interception, tun2socks/HEV tunnel, SOCKS proxy, or packet-payload inspection is used.

## Current Demo Behaviour

The core demo is intentionally simple:

- Start MindGuard protection.
- Browse normally.
- A request for `betika.com` is matched by the local policy and blocked.
- A request for a domain that is not blocked continues normally.
- Block events are surfaced to the Flutter UI.
- The user can maintain the local blocked-domain list.

The demo is not intended to be a complete HTTPS inspection product. Direct-IP connections, DNS-over-HTTPS/Private DNS implementations inside some apps, or previously cached DNS results may bypass this DNS-only layer.

## Architecture

### Flutter

- `lib/main.dart`
- `lib/providers/vpn_provider.dart`
- `lib/screens/clock_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/blocked_domains_screen.dart`
- `lib/screens/blocked_sites_screen.dart`
- `lib/services/vpn_service.dart`
- `lib/services/blocked_domains_service.dart`
- `lib/services/admin_service.dart`
- `lib/services/network_service.dart`
- `lib/services/ai_trust_service.dart`

### Android

- `MainActivity.kt` — Flutter/native method channels.
- `LocalVpnService.kt` — DNS-only VpnService and local DNS response handling.
- `DnsResolver.kt` — small facade over the local decision engine.
- `LocalDecisionEngine.kt` — fast, local, exact/suffix-aware domain policy.
- `PolicyLists.kt` — small built-in demo block/allow policy.
- `AdminReceiver.kt` — optional device-admin protection.
- `BootReceiver.kt` / `NetworkChangeReceiver.kt` — existing persistence/automation hooks.

## AI Domain Intelligence

`lib/services/ai_trust_service.dart` contains the optional Gemini integration.

The UI presents an "AI Domain Intelligence" card that:

- Displays the current local not-trusted domain snapshot.
- Applies newly suggested domains to the local blocked list.
- Refreshes the list at a six-hour interval while the dashboard is open.
- Can be refreshed manually.
- Does not send browsing history or page contents to Gemini.
- Uses a local fallback list when no key is configured.

### Gemini API key location

Open:

`lib/services/ai_trust_service.dart`

Look for:

```dart
static const _demoGeminiApiKey = 'PASTE_YOUR_GEMINI_API_KEY_HERE';
```

A safer build-time option is:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
```

A production version should move the AI call behind a backend because any key embedded into a mobile APK can ultimately be extracted.

## Clock Camouflage

The app launches into the clock screen.

- First installation guides the user through setting a secret time.
- The password is stored in Android secure storage.
- Long-pressing the centre enters edit mode.
- The hands are moved through the same long-press gesture.
- Tapping the centre confirms the selected time.
- Correct time unlocks the actual dashboard.

The minute-hand drag now uses the long-press movement recognizer instead of a competing pan recognizer.

## Network Privacy Model

MindGuard does not inspect or decrypt HTTPS payloads.

The VPN service processes only DNS requests directed to its private DNS endpoint. Allowed/unknown DNS queries are forwarded through a protected socket; the rest of the device traffic is not relayed through a MindGuard proxy.

This means there is no application-side browsing-content telemetry in the demo.

## Performance Goal

This branch intentionally avoids:

- HEV/tun2socks.
- Local SOCKS5 proxying.
- TLS/SNI/ECH inspection.
- IP correlation caches.
- Full-device packet forwarding.
- Busy one-millisecond packet polling.

The VPN loop uses blocking I/O and handles only the DNS packets required for the demo.

## Testing

CI currently runs Flutter analysis/tests and Android unit tests, then builds the release APK.

Manual device test:

1. Install the APK.
2. Complete the clock password setup.
3. Enter the dashboard.
4. Start protection.
5. Open a browser and try `betika.com`.
6. Verify the request is blocked.
7. Open an allowed domain such as `google.com`.
8. Verify ordinary browsing still works.
9. Stop protection and verify browsing returns to normal.

## Scope

This is a proof-of-concept architecture. More advanced inspection, category intelligence, app-specific controls, scheduling, background AI refresh, and backend-managed threat intelligence can be added later, but they are deliberately not in the hot path of this lightweight demo.
