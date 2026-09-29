import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';

class BlockedDomainsScreen extends StatefulWidget {
  const BlockedDomainsScreen({super.key});

  @override
  State<BlockedDomainsScreen> createState() => _BlockedDomainsScreenState();
}

class _BlockedDomainsScreenState extends State<BlockedDomainsScreen> {
  final TextEditingController _domainController = TextEditingController();

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  void _showAddDomainDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Blocked Domain'),
        content: TextField(
          controller: _domainController,
          decoration: const InputDecoration(
            hintText: 'example.com',
            labelText: 'Domain',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _domainController.clear();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final domain = _domainController.text.trim();
              if (domain.isNotEmpty) {
                final vpnProvider = context.read<VpnProvider>();
                await vpnProvider.addBlockedDomain(domain);

                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $domain to blocked list')),
                );
                _domainController.clear();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset the blocked domains list to the default list of porn and gambling sites. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final vpnProvider = context.read<VpnProvider>();
              await vpnProvider.resetToDefaultDomains();

              if (!mounted) return;

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to default domains')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Domains'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          final domains = vpnProvider.blockedDomains;

          if (domains.isEmpty) {
            return const Center(
              child: Text('No blocked domains'),
            );
          }

          return ListView.builder(
            itemCount: domains.length,
            itemBuilder: (context, index) {
              final domain = domains[index];
              return ListTile(
                leading: const Icon(Icons.block),
                title: Text(domain),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await vpnProvider.removeBlockedDomain(domain);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed $domain')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDomainDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
