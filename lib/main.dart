import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'oven_player.dart';
import 'secure/secure_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MaterialApp(home: OvenPlayer()));
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final sp = SecurePlayer();
  String status = 'Pick a video';

  @override
  void initState() {
    super.initState();
    sp.player.stream.error.listen((e) {
      print('Player error: $e');
      setState(() => status = 'Error: $e');
    });
    sp.player.stream.playing.listen((p) {
      print('Player playing: $p');
      if (p) setState(() => status = 'Playing');
    });
    sp.player.stream.log.listen((e) {
      print('Player log: $e');
    });
  }

  void _play(String id) {
    setState(() => status = 'Loading $id...');
    sp.playVideo(id, 'dev-token').catchError((e) => setState(() => status = 'Error: $e'));
  }

  @override
  void dispose() {
    sp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(status)),
    body: Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: sp.controller),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () => _play('enc'), child: const Text('Encrypted')),
            ElevatedButton(onPressed: () => _play('plain'), child: const Text('Plain')),
          ],
        ),
      ],
    ),
  );
}
