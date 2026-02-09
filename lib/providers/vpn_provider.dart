import 'package:flutter/foundation.dart';
import '../services/vpn_service.dart';
import '../services/blocked_domains_service.dart';
import '../services/admin_service.dart';
import '../services/network_service.dart';

class VpnProvider with ChangeNotifier {
  final VpnService _vpnService = VpnService();
  final BlockedDomainsService _domainsService = BlockedDomainsService();
  final AdminService _adminService = AdminService();
  final NetworkService _networkService = NetworkService();
  
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isAdminEnabled = false;
  bool _isAutoToggleEnabled = false;
  List<String> _blockedDomains = [];
  final List<String> _blockedSites = [];
  
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isAdminEnabled => _isAdminEnabled;
  bool get isAutoToggleEnabled => _isAutoToggleEnabled;
  List<String> get blockedDomains => _blockedDomains;
  List<String> get blockedSites => _blockedSites;
  
  VpnProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    _vpnService.connectionStateStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
    
    _vpnService.blockedSitesStream.listen((site) {
      _blockedSites.insert(0, site);
      if (_blockedSites.length > 100) {
        _blockedSites.removeLast();
      }
      notifyListeners();
    });
    
    await loadBlockedDomains();
    await checkAdminStatus();
    await checkAutoToggleStatus();
  }
  
  Future<void> loadBlockedDomains() async {
    _blockedDomains = await _domainsService.getBlockedDomains();
    await _vpnService.updateBlockedDomains(_blockedDomains);
    notifyListeners();
  }
  
  Future<void> checkAdminStatus() async {
    _isAdminEnabled = await _adminService.isDeviceAdminEnabled();
    notifyListeners();
  }

  Future<void> checkAutoToggleStatus() async {
    _isAutoToggleEnabled = await _networkService.isAutoToggleEnabled();
    notifyListeners();
  }

  Future<void> toggleAutoToggle(bool enabled) async {
    await _networkService.setAutoToggleEnabled(enabled);
    _isAutoToggleEnabled = enabled;
    notifyListeners();
  }
  
  Future<bool> toggleVpn() async {
    _isLoading = true;
    notifyListeners();
    
    bool success;
    if (_isConnected) {
      success = await _vpnService.stopVpn();
    } else {
      // Check and request VPN permission
      bool hasPermission = await _vpnService.checkVpnPermission();
      if (!hasPermission) {
        hasPermission = await _vpnService.requestVpnPermission();
      }
      
      if (hasPermission) {
        success = await _vpnService.startVpn();
      } else {
        success = false;
      }
    }
    
    _isLoading = false;
    notifyListeners();
    return success;
  }
  
  Future<bool> requestAdminPrivileges() async {
    final result = await _adminService.requestDeviceAdmin();
    await checkAdminStatus();
    return result;
  }
  
  Future<void> addBlockedDomain(String domain) async {
    await _domainsService.addBlockedDomain(domain);
    await loadBlockedDomains();
  }
  
  Future<void> removeBlockedDomain(String domain) async {
    await _domainsService.removeBlockedDomain(domain);
    await loadBlockedDomains();
  }
  
  Future<void> resetToDefaultDomains() async {
    await _domainsService.resetToDefaults();
    await loadBlockedDomains();
  }
  
  void clearBlockedSitesList() {
    _blockedSites.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _vpnService.dispose();
    super.dispose();
  }
}
