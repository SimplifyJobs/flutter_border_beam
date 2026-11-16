import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'demo_harness.dart';
import 'src/tokens.dart';
import 'src/wave_scenes.dart';

/// The distortion wave reel. Record with:
///
///   tool/record_demo.sh --target lib/wave_reel.dart --prefix WAVE --contact
///
/// Each scene is one of the wave page's demos on the dark theme: a beat on
/// the first screen, the wave out from its button — leaning toward where a
/// finger would have touched it — a beat on the revealed screen, and the
/// wave back into the button. The three types, then a border-beam palette.
Future<void> main() => runDemoReel(
  prefix: 'WAVE',
  hold: const Duration(seconds: 10),
  scenes: {
    'vertical': () =>
        const _Scene(WaveDemo.send, touch: Alignment(-0.45, -0.2)),
    'horizontal': () => const _Scene(WaveDemo.step, touch: Alignment(0, -0.3)),
    'center': () => const _Scene(WaveDemo.success),
    'beam_palette': () => const _Scene(
      WaveDemo.send,
      palette: 'aurora',
      touch: Alignment(0.5, 0.2),
    ),
  },
);

/// One demo playing itself: out, a beat, and back.
class _Scene extends StatefulWidget {
  const _Scene(this.demo, {this.palette, this.touch});

  final WaveDemo demo;

  /// A name in [wavePalettes]; the demo's own if null.
  final String? palette;

  /// Where on the anchor the reel "touches", which the vertical and
  /// horizontal waves lean toward; no lean if null.
  final Alignment? touch;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  final DistortionWaveController _wave = DistortionWaveController();
  final GlobalKey _anchor = GlobalKey(debugLabel: 'reel anchor');
  WaveSource? _source;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aim());
    _timer = Timer(const Duration(milliseconds: 900), _wave.reveal);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    super.dispose();
  }

  // The reel has no finger to press the anchor, so it names the anchor as
  // the source, touched where a finger would have been. Set before the
  // first run, so the collapse goes back into it too.
  void _aim() {
    if (!mounted) return;
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    final touch = widget.touch;
    final focus = box == null || touch == null
        ? null
        : box.localToGlobal(touch.alongSize(box.size));
    setState(() => _source = WaveSource.key(_anchor, focus: focus));
  }

  // Arrived on the revealed screen: hold it a beat, then collapse.
  void _finished() {
    if (!_wave.isRevealed) return;
    _timer = Timer(const Duration(milliseconds: 1200), _wave.collapse);
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo;
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 360,
          height: demo == WaveDemo.success ? sheetHeight : 680,
          child: DemoWave(
            demo: demo,
            controller: _wave,
            palette: wavePalettes[widget.palette ?? demo.palette]!,
            source: _source,
            anchorKey: _anchor,
            chain: false,
            onFinish: _finished,
          ),
        ),
      ),
    );
  }
}
