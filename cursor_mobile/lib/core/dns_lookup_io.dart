import 'dart:io';

/// Resolve api.cursor.com from this process (same DNS as the app uses).
Future<String> dnsLookupApiCursor() async {
  try {
    final res = await InternetAddress.lookup('api.cursor.com');
    if (res.isEmpty) return 'DNS: no addresses for api.cursor.com';
    return 'DNS OK — ${res.map((e) => e.address).join(', ')}';
  } catch (e) {
    return 'DNS failed: $e';
  }
}

/// Raw HTTPS GET to api root (no API key). Proves TLS + routing from this app.
Future<String> httpPingApiCursor() async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('https://api.cursor.com/'));
    req.followRedirects = true;
    final resp = await req.close();
    final code = resp.statusCode;
    await resp.drain();
    return 'HTTPS OK — HTTP $code (this app can reach Cursor)';
  } catch (e) {
    return 'HTTPS failed: $e';
  } finally {
    client.close();
  }
}
