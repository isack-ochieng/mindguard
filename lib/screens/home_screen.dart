import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import 'blocked_domains_screen.dart';
import 'blocked_sites_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Filter VPN'),
        elevation: 2,
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // VPN Status Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          vpnProvider.isConnected
                              ? Icons.shield_outlined
                              : Icons.shield,
                          size: 80,
                          color: vpnProvider.isConnected
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          vpnProvider.isConnected
                              ? 'VPN Connected'
                              : 'VPN Disconnected',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vpnProvider.isConnected
                              ? 'Content filtering is active'
                              : 'Tap to enable content filtering',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: vpnProvider.isLoading
                                ? null
                                : () async {
                                    final success = await vpnProvider.toggleVpn();
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to toggle VPN'),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: vpnProvider.isConnected
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: vpnProvider.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    vpnProvider.isConnected
                                        ? 'Disconnect'
                                        : 'Connect',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Auto-Toggle Card
                Card(
                  elevation: 2,
                  child: SwitchListTile(
                    title: const Text('Auto-Toggle VPN'),
                    subtitle: const Text('Automatically start/stop VPN when Wi-Fi or Mobile Data connects/disconnects'),
                    value: vpnProvider.isAutoToggleEnabled,
                    onChanged: (value) {
                      vpnProvider.toggleAutoToggle(value);
                    },
                    secondary: const Icon(Icons.network_check),
                  ),
                ),

                const SizedBox(height: 16),

                // Admin Status Card
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      vpnProvider.isAdminEnabled
                          ? Icons.admin_panel_settings
                          : Icons.admin_panel_settings_outlined,
                      color: vpnProvider.isAdminEnabled
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: const Text('Device Admin'),
                    subtitle: Text(
                      vpnProvider.isAdminEnabled
                          ? 'Enabled - App is protected'
                          : 'Disabled - Tap to enable protection',
                    ),
                    trailing: vpnProvider.isAdminEnabled
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.warning, color: Colors.orange),
                    onTap: vpnProvider.isAdminEnabled
                        ? null
                        : () async {
                            final success = await vpnProvider.requestAdminPrivileges();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Admin privileges granted'
                                        : 'Admin privileges denied',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Statistics Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              icon: Icons.block,
                              label: 'Blocked Domains',
                              value: vpnProvider.blockedDomains.length.toString(),
                            ),
                            _StatItem(
                              icon: Icons.history,
                              label: 'Sites Blocked',
                              value: vpnProvider.blockedSites.length.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Management Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BlockedDomainsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('Manage Blocked Domains'),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BlockedSitesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View Blocked Sites History'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
