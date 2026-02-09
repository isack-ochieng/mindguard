import 'package:shared_preferences.dart';

class BlockedDomainsService {
  static const String _blockedDomainsKey = 'blocked_domains';
  
  // Default list of blocked domains (porn and gambling sites)
  static final List<String> defaultBlockedDomains = [
    // Porn sites
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
    'redtube.com',
    'youporn.com',
    'tube8.com',
    'spankbang.com',
    'porn.com',
    'sex.com',
    'xxx.com',
    'brazzers.com',
    'onlyfans.com',
    'chaturbate.com',
    'livejasmin.com',
    'stripchat.com',
    'cam4.com',
    'myfreecams.com',
    
    // Gambling sites
    'bet365.com',
    'betway.com',
    'draftkings.com',
    'fanduel.com',
    'pokerstars.com',
    '888casino.com',
    'williamhill.com',
    'unibet.com',
    'bwin.com',
    'betfair.com',
    'ladbrokes.com',
    'paddypower.com',
    'coral.co.uk',
    'skybet.com',
    'betfred.com',
    'bovada.lv',
    'betonline.ag',
    'mybookie.ag',
    'sportsbetting.ag',
    'intertops.eu',
    'casino.com',
    'jackpotcity.com',
    'spin casino.com',
    'royal vegas.com',
    'casumo.com',
    'leovegas.com',
    'betmgm.com',
    'caesars.com',
    'borgata.com',
  ];
  
  Future<List<String>> getBlockedDomains() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedDomains = prefs.getStringList(_blockedDomainsKey);
    
    if (savedDomains == null || savedDomains.isEmpty) {
      // Initialize with default domains
      await saveBlockedDomains(defaultBlockedDomains);
      return defaultBlockedDomains;
    }
    
    return savedDomains;
  }
  
  Future<bool> saveBlockedDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setStringList(_blockedDomainsKey, domains);
  }
  
  Future<bool> addBlockedDomain(String domain) async {
    final domains = await getBlockedDomains();
    if (!domains.contains(domain.toLowerCase())) {
      domains.add(domain.toLowerCase());
      return await saveBlockedDomains(domains);
    }
    return false;
  }
  
  Future<bool> removeBlockedDomain(String domain) async {
    final domains = await getBlockedDomains();
    if (domains.contains(domain.toLowerCase())) {
      domains.remove(domain.toLowerCase());
      return await saveBlockedDomains(domains);
    }
    return false;
  }
  
  Future<void> resetToDefaults() async {
    await saveBlockedDomains(defaultBlockedDomains);
  }
  
  bool isDomainBlocked(String url, List<String> blockedDomains) {
    final lowerUrl = url.toLowerCase();
    for (final domain in blockedDomains) {
      if (lowerUrl.contains(domain.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
