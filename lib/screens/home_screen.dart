import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/vpn_provider.dart';
import '../services/ai_trust_service.dart';
import 'blocked_domains_screen.dart';
import 'blocked_sites_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindGuard'),
        elevation: 2,
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                              ? 'Protection Active'
                              : 'Protection Off',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vpnProvider.isConnected
                              ? 'MindGuard is checking DNS requests against the local protection list.'
                              : 'Enable the VPN to start the lightweight domain filter.',
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
                                    final success =
                                        await vpnProvider.toggleVpn();
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to start the VPN filter',
                                          ),
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
                                        ? 'Stop Protection'
                                        : 'Start Protection',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const _AiTrustCard(),

                const SizedBox(height: 16),

                Card(
                  elevation: 2,
                  child: SwitchListTile(
                    title: const Text('Auto-Toggle VPN'),
                    subtitle: const Text(
                      'Start and stop protection with network changes',
                    ),
                    value: vpnProvider.isAutoToggleEnabled,
                    onChanged: vpnProvider.toggleAutoToggle,
                    secondary: const Icon(Icons.network_check),
                  ),
                ),

                const SizedBox(height: 16),

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
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          )
                        : const Icon(Icons.warning, color: Colors.orange),
                    onTap: vpnProvider.isAdminEnabled
                        ? null
                        : () async {
                            final success =
                                await vpnProvider.requestAdminPrivileges();
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
                              value:
                                  vpnProvider.blockedDomains.length.toString(),
                            ),
                            _StatItem(
                              icon: Icons.history,
                              label: 'Sites Blocked',
                              value:
                                  vpnProvider.blockedSites.length.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const BlockedDomainsScreen(),
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

class _AiTrustCard extends StatefulWidget {
  const _AiTrustCard();

  @override
  State<_AiTrustCard> createState() => _AiTrustCardState();
}

class _AiTrustCardState extends State<_AiTrustCard> {
  static const _refreshInterval = Duration(hours: 6);

  final AiTrustService _aiService = AiTrustService();
  Timer? _periodicTimer;

  AiTrustUpdate? _update;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAiList();
    });

    // The list is refreshed periodically while this screen is alive.
    // The VPN itself never waits for this timer.
    _periodicTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshAiList();
    });
  }

  Future<void> _initializeAiList() async {
    final cached = await _aiService.loadCached();
    if (!mounted) return;

    setState(() => _update = cached);
    await _applyDomains(cached.domains);

    // Refresh only when the cached snapshot is older than the interval.
    final stale = cached.updatedAt == DateTime.fromMillisecondsSinceEpoch(0) ||
        DateTime.now().difference(cached.updatedAt) >= _refreshInterval;

    if (stale) {
      await _refreshAiList();
    }
  }

  Future<void> _refreshAiList() async {
    if (_loading) return;

    setState(() => _loading = true);
    final update = await _aiService.refresh();
    await _applyDomains(update.domains);

    if (!mounted) return;
    setState(() {
      _update = update;
      _loading = false;
    });
  }

  Future<void> _applyDomains(List<String> domains) async {
    final provider = context.read<VpnProvider>();

    for (final domain in domains) {
      if (!provider.blockedDomains.contains(domain)) {
        await provider.addBlockedDomain(domain);
      }
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final domains = update?.domains ?? const <String>[];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI Domain Intelligence',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh AI list',
                    onPressed: _refreshAiList,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              update?.message ??
                  'Building a local list of domains marked not trusted.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (domains.isEmpty)
              const Text('No domains have been suggested yet.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: domains.take(8).map((domain) {
                  return Chip(
                    avatar: const Icon(Icons.gpp_bad_outlined, size: 18),
                    label: Text(domain),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Text(
              update?.usedGemini == true
                  ? 'Gemini updates this local list periodically. '
                      'Browsing history and page contents are not sent.'
                  : 'Local demo list is active. Add your Gemini key in '
                      'lib/services/ai_trust_service.dart to enable AI updates.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
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
