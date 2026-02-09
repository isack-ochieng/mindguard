import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';

class BlockedSitesScreen extends StatelessWidget {
  const BlockedSitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Sites History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear history',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text(
                    'Are you sure you want to clear the blocked sites history?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<VpnProvider>().clearBlockedSitesList();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('History cleared')),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          final blockedSites = vpnProvider.blockedSites;

          if (blockedSites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sites blocked yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Blocked sites will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedSites.length,
            itemBuilder: (context, index) {
              final site = blockedSites[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: Icon(
                      Icons.block,
                      color: Colors.red[700],
                    ),
                  ),
                  title: Text(
                    site,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  subtitle: Text(
                    'Blocked ${_getTimeAgo(index)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(int index) {
    // Simple time estimation based on position in list
    if (index == 0) return 'just now';
    if (index < 5) return 'recently';
    if (index < 20) return 'a while ago';
    return 'earlier';
  }
}
