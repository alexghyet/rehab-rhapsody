import 'package:flutter/material.dart';

import '../audio/asset_demo_audio_engine.dart';
import '../audio/asset_song_audio_player.dart';
import '../baton/universal_baton_transport.dart';
import '../home/home_controller.dart';
import '../home/home_options.dart';
import '../home/home_screen.dart';
import '../songs/song_session.dart';
import 'demo_controller.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, this.controller});
  final DemoController? controller;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late DemoController _demo;

  DemoController _createDemo() => DemoController(
    home: HomeController()..selectMode(PlayMode.song),
    transport: UniversalBatonTransport(),
    audio: AssetDemoAudioEngine(),
    songSession: SongSession(audio: AssetSongAudioPlayer()),
  );

  @override
  void initState() {
    super.initState();
    _demo = widget.controller ?? _createDemo();
  }

  @override
  void didUpdateWidget(covariant DemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _releaseDemo(owned: oldWidget.controller == null);
    _demo = widget.controller ?? _createDemo();
  }

  void _releaseDemo({required bool owned}) {
    if (owned) {
      _demo.dispose();
      _demo.home.dispose();
    } else {
      _demo.pause();
    }
  }

  @override
  void dispose() {
    _releaseDemo(owned: widget.controller == null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HomeScreen(controller: _demo.home, demo: _demo);
}
