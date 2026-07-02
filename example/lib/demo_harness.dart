import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single named scene in a demo reel: the widget (usually a `BorderBeam`
/// around a mock surface) that should be shown centered on the stage while
/// the recorder captures it.
typedef DemoScene = Widget Function();

/// Boots a full-screen "reel" used to record demo videos (see
/// `tool/record_demo.sh`). Writing a new demo is just a map of name → scene.
///
/// The stage is the border-beam demo backdrop (`#070707`); each scene is
/// mounted centered for [hold], then removed, with a clean [gap] between
/// scenes for slicing.
///
/// Around the reel it prints the log markers the recorder keys off:
///
///   `<prefix>:<name>:START`   `<prefix>:<name>:END`   …   `<prefix>:DONE`
///
/// The recorder waits for the first `<prefix>:DONE` (build is good, screen is
/// clean), starts recording, hot-restarts to replay, and stops at the second
/// `<prefix>:DONE`. Keeping the marker contract here means new demos need
/// zero recorder changes.
void runDemoReel({
  required String prefix,
  required Map<String, DemoScene> scenes,
  Duration hold = const Duration(seconds: 6),
  Color backdrop = const Color(0xFF070707),
  Duration settle = const Duration(seconds: 2),
  Duration gap = const Duration(milliseconds: 1800),
}) {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(
    _DemoReelApp(
      prefix: prefix,
      scenes: scenes,
      hold: hold,
      backdrop: backdrop,
      settle: settle,
      gap: gap,
    ),
  );
}

class _DemoReelApp extends StatelessWidget {
  const _DemoReelApp({
    required this.prefix,
    required this.scenes,
    required this.hold,
    required this.backdrop,
    required this.settle,
    required this.gap,
  });

  final String prefix;
  final Map<String, DemoScene> scenes;
  final Duration hold;
  final Color backdrop;
  final Duration settle;
  final Duration gap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: _DemoReelStage(
        prefix: prefix,
        scenes: scenes,
        hold: hold,
        backdrop: backdrop,
        settle: settle,
        gap: gap,
      ),
    );
  }
}

class _DemoReelStage extends StatefulWidget {
  const _DemoReelStage({
    required this.prefix,
    required this.scenes,
    required this.hold,
    required this.backdrop,
    required this.settle,
    required this.gap,
  });

  final String prefix;
  final Map<String, DemoScene> scenes;
  final Duration hold;
  final Color backdrop;
  final Duration settle;
  final Duration gap;

  @override
  State<_DemoReelStage> createState() => _DemoReelStageState();
}

class _DemoReelStageState extends State<_DemoReelStage> {
  Widget? _current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runReel());
  }

  Future<void> _runReel() async {
    await Future<void>.delayed(widget.settle); // settle on launch / restart
    for (final entry in widget.scenes.entries) {
      await _clean();
      debugPrint('${widget.prefix}:${entry.key}:START');
      if (mounted) setState(() => _current = entry.value());
      await Future<void>.delayed(widget.hold);
      debugPrint('${widget.prefix}:${entry.key}:END');
    }
    await _clean();
    debugPrint('${widget.prefix}:DONE');
  }

  Future<void> _clean() async {
    if (mounted) setState(() => _current = null);
    await Future<void>.delayed(widget.gap);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: widget.backdrop,
        child: SizedBox.expand(
          child: Center(child: _current ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
