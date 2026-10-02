import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiTrustUpdate {
  final List<String> domains;
  final DateTime updatedAt;
  final bool usedGemini;
  final String message;

  const AiTrustUpdate({
    required this.domains,
    required this.updatedAt,
    required this.usedGemini,
    required this.message,
  });
}

class AiTrustService {
  // ================================================================
  // GEMINI API KEY — THIS IS THE EXACT PLACE FOR YOUR KEY.
  //
  // QUICK DEMO:
  //   Replace the placeholder between the quotes below.
  //
  // SAFER BUILD:
  //   flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
  //
  // Do not commit a real API key to GitHub. A mobile app cannot make
  // a client-side API key completely secret because the APK is yours
  // to inspect. For production, move this call behind your backend.
  // ================================================================
  static const _demoGeminiApiKey = 'PASTE_YOUR_GEMINI_API_KEY_HERE';

  static const _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: _demoGeminiApiKey,
  );

  static const _model = 'gemini-3.6-flash';

  static const _cachedDomainsKey = 'ai_not_trusted_domains';
  static const _cachedUpdatedAtKey = 'ai_not_trusted_updated_at';

  // This candidate list is static. No browsing history or URLs visited
  // by the user are sent to Gemini.
  static const candidateDomains = <String>[
    'betika.com',
    'betway.com',
    'bet365.com',
    '1xbet.com',
    'sportpesa.com',
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'google.com',
    'github.com',
    'wikipedia.org',
  ];

  bool get isConfigured =>
      _geminiApiKey.isNotEmpty &&
      _geminiApiKey != _demoGeminiApiKey;

  Future<AiTrustUpdate> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_cachedDomainsKey) ?? <String>[];
    final updatedAtMs = prefs.getInt(_cachedUpdatedAtKey);

    if (domains.isEmpty || updatedAtMs == null) {
      return AiTrustUpdate(
        domains: _demoFallbackDomains,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        usedGemini: false,
        message: isConfigured
            ? 'No AI snapshot yet.'
            : 'Demo list active — add your Gemini key to enable AI updates.',
      );
    }

    return AiTrustUpdate(
      domains: domains,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      usedGemini: isConfigured,
      message: isConfigured ? 'Cached AI snapshot.' : 'Cached local snapshot.',
    );
  }

  Future<AiTrustUpdate> refresh() async {
    if (!isConfigured) {
      return AiTrustUpdate(
        domains: _demoFallbackDomains,
        updatedAt: DateTime.now(),
        usedGemini: false,
        message: 'Local demo list active. No data is sent anywhere.',
      );
    }

    final prompt = '''
You are the domain-classification component of a defensive Android
content-filtering demo called MindGuard.

Classify ONLY the domains in this candidate list.
Return ONLY valid JSON in exactly this shape:
{"domains":["domain1.com","domain2.com"]}

Include only domains that should be treated as NOT TRUSTED for a simple
content-safety demo (for example gambling or adult-content domains).
Do not invent domains. Do not include explanations.

Candidate domains:
${candidateDomains.join(', ')}
''';

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
            ),
            headers: <String, String>{
              'x-goog-api-key': _geminiApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'contents': <Object>[
                <String, Object>{
                  'parts': <Object>[
                    <String, String>{'text': prompt},
                  ],
                },
              ],
              'generationConfig': <String, Object>{
                'temperature': 0.1,
                'maxOutputTokens': 300,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = _extractGeneratedText(decoded);
      final domains = _extractDomains(text);

      if (domains.isEmpty) {
        throw Exception('Gemini returned no usable domains');
      }

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_cachedDomainsKey, domains);
      await prefs.setInt(_cachedUpdatedAtKey, now.millisecondsSinceEpoch);

      return AiTrustUpdate(
        domains: domains,
        updatedAt: now,
        usedGemini: true,
        message: 'AI refreshed the local trust list.',
      );
    } catch (_) {
      final fallback = await loadCached();
      return AiTrustUpdate(
        domains: fallback.domains.isEmpty
            ? _demoFallbackDomains
            : fallback.domains,
        updatedAt: fallback.updatedAt,
        usedGemini: false,
        message: 'AI update unavailable; local protection remains active.',
      );
    }
  }

  String _extractGeneratedText(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates');
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Invalid Gemini candidate');
    }

    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw Exception('Invalid Gemini content');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('Gemini returned no content parts');
    }

    final texts = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .toList();

    if (texts.isEmpty) {
      throw Exception('Gemini returned no text');
    }

    return texts.join();
  }

  List<String> _extractDomains(String rawText) {
    final decoded = jsonDecode(rawText.trim());

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected a JSON object');
    }

    final values = decoded['domains'];
    if (values is! List) {
      throw Exception('Missing domains array');
    }

    final allowed = candidateDomains.toSet();

    return values
        .whereType<String>()
        .map(_normalizeDomain)
        .where((domain) => allowed.contains(domain))
        .toSet()
        .toList();
  }

  String _normalizeDomain(String domain) {
    final normalized = domain.trim().toLowerCase();
    return normalized.endsWith('.')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static const _demoFallbackDomains = <String>[
    'betika.com',
    'betway.com',
    'bet365.com',
    '1xbet.com',
    'sportpesa.com',
    'pornhub.com',
  ];
}
