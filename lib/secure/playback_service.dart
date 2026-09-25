import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class PlaybackInfo {
  final String url;
  final bool encrypted;
  final String? keyHex;
  const PlaybackInfo(this.url, this.encrypted, this.keyHex);
}

class PlaybackService {
  // -------- TEST MODE --------
  static const bool testMode = true;
  static const String testBase = 'http://127.0.0.1:8000'; // works via `adb reverse`
  static const String testKeyHex = 'c321a7cef608da697b88bbc2a36a1b3ee8d5ac62e53c6b7ae7e4cef086b12fdb';

  // -------- PRODUCTION --------
  // Backend returns: {"url":"...m3u8","encrypted":true,"key":"<hex>"}  or  {"url":"...","encrypted":false}
  static const String host = 'api.example.com';
  static const String pinnedCertSha256 = 'PASTE_CERT_SHA256_HERE';

  static final RegExp _hexKey = RegExp(r'^([0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})$');

  static Future<PlaybackInfo> get(String videoId, String userToken) async {
    if (testMode) {
      if (videoId == 'enc') {
        final keyBase64 = 'mIHGjIsmZbrAJtGM8NlxqLC8L7oJ2gFU5ZGPNBQ+nF4=';
        final keyBytes = base64.decode(keyBase64); // 32 bytes
        final hex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        return PlaybackInfo('https://spcmedia.classiolabs.com/classiospc/video/1790175410977/720/index.m3u8', true, _check(hex));
      }
      return const PlaybackInfo('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', false, null);
    }

    final client = HttpClient()..badCertificateCallback = (_, _, _) => false;
    try {
      final req = await client.getUrl(Uri.https(host, '/v1/playback/$videoId'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $userToken');
      final res = await req.close();
      final cert = res.certificate;
      if (cert == null || sha256.convert(cert.der).toString() != pinnedCertSha256) {
        throw const HandshakeException('Certificate pin mismatch');
      }
      if (res.statusCode != 200) {
        throw HttpException('Playback info failed: ${res.statusCode}');
      }
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final encrypted = j['encrypted'] == true;
      return PlaybackInfo(j['url'] as String, encrypted, encrypted ? _check(j['key'] as String) : null);
    } finally {
      client.close(force: true);
    }
  }

  static String _check(String k) {
    if (!_hexKey.hasMatch(k)) throw const FormatException('Bad AES key');
    return k;
  }
}
