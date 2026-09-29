import 'package:shared_preferences/shared_preferences.dart';

class BlockedDomainsService {
  static const String _blockedDomainsKey = 'blocked_domains';

  // Seed policy list. The native local decision engine also carries the
  // built-in policy so filtering does not depend on Flutter being alive.
  static final List<String> defaultBlockedDomains = [
    // Adult
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

    // Gambling
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
    'casumo.com',
    'leovegas.com',
    'betmgm.com',
    'caesars.com',
    'borgata.com',
  ];

  Future<List<String>> getBlockedDomains() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDomains = prefs.getStringList(_blockedDomainsKey);

    if (savedDomains == null) {
      await saveBlockedDomains(defaultBlockedDomains);
      return List<String>.from(defaultBlockedDomains);
    }

    return savedDomains
        .map(normalizeDomain)
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<bool> saveBlockedDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = domains
        .map(normalizeDomain)
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList();
    return prefs.setStringList(_blockedDomainsKey, normalized);
  }

  Future<bool> addBlockedDomain(String domain) async {
    final normalized = normalizeDomain(domain);
    if (normalized.isEmpty) return false;

    final domains = await getBlockedDomains();
    if (!domains.contains(normalized)) {
      domains.add(normalized);
      return saveBlockedDomains(domains);
    }
    return false;
  }

  Future<bool> removeBlockedDomain(String domain) async {
    final normalized = normalizeDomain(domain);
    final domains = await getBlockedDomains();

    if (domains.remove(normalized)) {
      return saveBlockedDomains(domains);
    }
    return false;
  }

  Future<void> resetToDefaults() async {
    await saveBlockedDomains(defaultBlockedDomains);
  }

  /// Domain-aware matching. For example:
  ///   example.com      -> matches example.com
  ///   www.example.com  -> matches example.com
  ///   example.com.evil -> does NOT match example.com
  bool isDomainBlocked(String domain, List<String> blockedDomains) {
    final normalized = normalizeDomain(domain);
    if (normalized.isEmpty) return false;

    return blockedDomains
        .map(normalizeDomain)
        .any((rule) => normalized == rule || normalized.endsWith('.$rule'));
  }

  String normalizeDomain(String value) {
    var domain = value.trim().toLowerCase();

    domain = domain
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')
        .first
        .split('?')
        .first
        .split('#')
        .first
        .split(':')
        .first
        .trim();

    return domain.endsWith('.') ? domain.substring(0, domain.length - 1) : domain;
  }
}
