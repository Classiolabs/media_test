import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A full-page HLS video player built with media_kit.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  static const _hlsUrl =
      'https://demo.unified-streaming.com/k8s/features/stable/video/'
      'tears-of-steel/tears-of-steel.ism/.m3u8';

  late final Player _player;
  late final VideoController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.error.listen((error) {
      print('Player error: $error');
      if (mounted) {
        setState(() => _error = error);
      }
    });
    _player.open(Media(_hlsUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('HLS Video (media_kit)')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(controller: _controller, controls: NoVideoControls),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            _PlayerControls(player: _player),
          ],
        ),
      ),
    );
  }
}

/// Play/pause, seek bar, and position display bound to the [Player] streams.
class _PlayerControls extends StatefulWidget {
  const _PlayerControls({required this.player});

  final Player player;

  @override
  State<_PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<_PlayerControls> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _subscriptions.add(
      player.stream.position.listen((value) {
        setState(() => _position = value);
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((value) {
        setState(() => _duration = value);
      }),
    );
    _subscriptions.add(
      player.stream.playing.listen((value) {
        setState(() => _playing = value);
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((value) {
        setState(() => _buffering = value);
      }),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${hours > 0 ? '$hours:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final positionMs = _position.inMilliseconds.toDouble();
    final durationMs = _duration.inMilliseconds.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: durationMs > 0 ? positionMs.clamp(0, durationMs) : 0,
            max: durationMs > 0 ? durationMs : 1,
            onChanged: (value) => player.seek(Duration(milliseconds: value.round())),
          ),
          Row(
            children: [
              IconButton(
                onPressed: player.playOrPause,
                color: Colors.white,
                icon: _buffering ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              Expanded(
                child: Text('${_format(_position)} / ${_format(_duration)}', style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
