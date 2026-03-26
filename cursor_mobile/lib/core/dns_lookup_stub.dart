/// Web / non-IO platforms: no native DNS/HTTP ping.
Future<String> dnsLookupApiCursor() async =>
    'DNS check runs only on Android / iOS / desktop.';

Future<String> httpPingApiCursor() async =>
    'HTTPS check runs only on Android / iOS / desktop.';
