import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback_service.dart';

class SecurePlayer {
  final Player player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error));
  late final VideoController controller = VideoController(player);
  NativePlayer get _native => player.platform as NativePlayer;

  Future<void> playVideo(String videoId, String userToken) async {
    final info = await PlaybackService.get(videoId, userToken);

    await player.stop();
    await _native.setProperty('cache-on-disk', 'no');
    // Must be set BEFORE open(): key for encrypted videos, empty for plain ones.
    await _native.setProperty('demuxer-lavf-o', info.encrypted ? 'aes_ecb_key=${info.keyHex}' : '');

    await player.open(Media(info.url, httpHeaders: {'Authorization': 'Bearer $userToken'}));
  }

  Future<void> dispose() async {
    try {
      await _native.setProperty('demuxer-lavf-o', '');
    } catch (_) {}
    await player.dispose();
  }
}
