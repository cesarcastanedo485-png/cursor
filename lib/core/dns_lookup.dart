import 'dns_lookup_stub.dart' if (dart.library.io) 'dns_lookup_io.dart' as impl;

/// Resolve [api.cursor.com] from the Dart VM (matches app networking).
Future<String> dnsLookupApiCursor() => impl.dnsLookupApiCursor();

/// HTTPS GET to https://api.cursor.com/ without auth (status proves reachability).
Future<String> httpPingApiCursor() => impl.httpPingApiCursor();
