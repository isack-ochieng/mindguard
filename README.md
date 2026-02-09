# Content Filter VPN

A Flutter mobile application that functions as a content filtering VPN to monitor phone traffic and restrict access to specific websites such as porn and gambling sites. The app includes persistent admin privileges to prevent easy deletion.

## Features

### Core Functionality
- **VPN-based Traffic Monitoring**: Intercepts and analyzes network traffic at the device level
- **Content Filtering**: Blocks access to predefined categories of websites (porn, gambling)
- **Real-time Blocking**: Instantly blocks connections to restricted domains
- **Blocked Sites History**: Tracks and displays recently blocked connection attempts

### Security & Persistence
- **Device Admin Privileges**: Utilizes Android Device Admin API to prevent unauthorized uninstallation
- **Auto-start on Boot**: Automatically restarts VPN service after device reboot
- **Persistent Service**: Runs as a foreground service to maintain continuous protection

### User Interface
- **Simple Dashboard**: Shows VPN connection status and statistics
- **Domain Management**: Add, remove, or reset blocked domains
- **History Viewer**: View list of blocked site attempts
- **Admin Status**: Visual indicator of device admin protection status

## Default Blocked Domains

The app comes pre-configured with a comprehensive list of blocked domains including:

### Porn Sites
- pornhub.com, xvideos.com, xnxx.com, xhamster.com
- redtube.com, youporn.com, tube8.com, spankbang.com
- And many more...

### Gambling Sites
- bet365.com, betway.com, draftkings.com, fanduel.com
- pokerstars.com, 888casino.com, williamhill.com
- And many more...

Users can customize this list by adding or removing domains as needed.

## Technical Architecture

### Flutter Layer
- **Provider Pattern**: State management using Provider package
- **Method Channels**: Communication between Flutter and native Android code
- **Services**: Modular service architecture for VPN, domains, and admin management

### Android Native Layer
- **VPN Service**: Custom VpnService implementation for traffic interception
- **Packet Analysis**: Deep packet inspection to identify and block restricted content
- **DNS Resolution**: Domain-based filtering with caching
- **Device Admin Receiver**: Handles admin privilege requests and lifecycle

## Installation & Setup

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Android SDK (API level 21 or higher)
- Android device or emulator

### Build Instructions

1. **Clone or navigate to the project directory**:
   ```bash
   cd content_filter_vpn
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Build the APK**:
   ```bash
   flutter build apk --release
   ```

4. **Install on device**:
   ```bash
   flutter install
   ```

   Or manually install the APK from:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

### First-Time Setup

1. **Launch the app** on your Android device
2. **Grant VPN Permission**: Tap "Connect" and approve the VPN connection request
3. **Enable Device Admin**: Tap on the "Device Admin" card to grant admin privileges
4. **Start Filtering**: Once both permissions are granted, the VPN will start filtering content

## Usage

### Connecting the VPN
1. Open the app
2. Tap the "Connect" button on the home screen
3. Approve the VPN permission dialog if prompted
4. Wait for the connection to establish (status will change to "VPN Connected")

### Managing Blocked Domains
1. Tap "Manage Blocked Domains" on the home screen
2. To add a domain: Tap the "+" button and enter the domain name
3. To remove a domain: Tap the delete icon next to the domain
4. To reset to defaults: Tap the refresh icon in the app bar

### Viewing Blocked Sites History
1. Tap "View Blocked Sites History" on the home screen
2. See a list of recently blocked connection attempts
3. Clear history using the delete icon in the app bar

### Enabling Device Admin Protection
1. Tap on the "Device Admin" card on the home screen
2. Review the permissions and tap "Activate"
3. Once enabled, the app cannot be easily uninstalled without first disabling admin

## Important Notes

### Permissions Required
- **VPN Permission**: Required to intercept and filter network traffic
- **Device Admin**: Optional but recommended to prevent unauthorized removal
- **Foreground Service**: Keeps the VPN running continuously
- **Boot Completed**: Allows auto-start after device reboot
- **Internet**: Required for network operations

### Limitations
1. **HTTPS Traffic**: Due to encryption, the app can only block based on DNS queries and initial connection attempts for HTTPS sites
2. **VPN Conflicts**: Cannot run simultaneously with other VPN apps
3. **Root Not Required**: The app does not require root access
4. **Battery Usage**: Running a VPN service continuously may impact battery life

### Security Considerations
1. **Device Admin**: Once enabled, the app must be manually deactivated from Settings > Security > Device Administrators before uninstallation
2. **Traffic Privacy**: All traffic is processed locally on the device; no data is sent to external servers
3. **No Logging**: The app does not permanently log browsing history beyond the in-memory blocked sites list

## Disabling/Uninstalling

### To Disable the VPN
1. Open the app
2. Tap "Disconnect" on the home screen

### To Uninstall the App

If Device Admin is enabled:
1. Go to Settings > Security > Device Administrators
2. Find "Content Filter VPN" and tap to deactivate
3. Confirm deactivation
4. Return to Settings > Apps > Content Filter VPN
5. Tap "Uninstall"

If Device Admin is not enabled:
1. Go to Settings > Apps > Content Filter VPN
2. Tap "Uninstall"

## Development

### Project Structure
```
lib/
├── main.dart                          # App entry point
├── providers/
│   └── vpn_provider.dart             # State management
├── screens/
│   ├── home_screen.dart              # Main dashboard
│   ├── blocked_domains_screen.dart   # Domain management
│   └── blocked_sites_screen.dart     # History viewer
└── services/
    ├── vpn_service.dart              # VPN service interface
    ├── blocked_domains_service.dart  # Domain storage
    └── admin_service.dart            # Admin management

android/app/src/main/kotlin/com/example/content_filter_vpn/
├── MainActivity.kt                    # Flutter-Android bridge
├── LocalVpnService.kt                # VPN service implementation
├── PacketAnalyzer.kt                 # Traffic analysis
├── DnsResolver.kt                    # Domain resolution
├── AdminReceiver.kt                  # Device admin receiver
└── BootReceiver.kt                   # Boot auto-start
```

### Testing
- Test on a physical Android device (VPN services don't work well in emulators)
- Verify VPN connection establishes successfully
- Test blocking by attempting to access blocked domains
- Verify admin protection prevents uninstallation
- Test auto-start after device reboot

## Troubleshooting

### VPN Won't Connect
- Ensure no other VPN apps are running
- Check that VPN permission was granted
- Restart the app and try again

### Sites Not Being Blocked
- Verify the VPN is connected (check status on home screen)
- Ensure the domain is in the blocked list
- Some apps may use IP addresses directly, bypassing DNS filtering

### Can't Uninstall App
- The app has device admin enabled
- Follow the uninstallation steps in the "Disabling/Uninstalling" section above

### Battery Drain
- VPN services run continuously and will consume battery
- Consider disconnecting when not needed
- Optimize by reducing the frequency of packet inspection if modifying the code

## Legal & Ethical Considerations

This app is designed for:
- Parental control purposes
- Self-control and productivity
- Educational and research purposes

**Important**: 
- Always obtain consent before installing monitoring software on someone else's device
- Respect privacy laws and regulations in your jurisdiction
- Use responsibly and ethically

## License

This project is provided as-is for educational purposes. Modify and use according to your needs.

## Support

For issues, questions, or contributions, please refer to the project repository or contact the developer.

---

**Version**: 1.0.0  
**Last Updated**: December 2025  
**Platform**: Android (API 21+)  
**Framework**: Flutter 3.10+
