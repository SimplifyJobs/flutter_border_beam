import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import '../demo_theme.dart';
import 'controls.dart';
import 'controls_panel.dart';
import 'playground_state.dart';
import 'preview.dart';
import 'share_codec.dart';
import 'snippet.dart';

/// The interactive playground: every meaningful knob of the package's API
/// wired to a live preview and a generated snippet.
///
/// The preview and the snippet are built from the same "only what differs
/// from the package default" rule, so what you read is what you see — with
/// the theme demo on, a control left at its default inherits from the
/// enclosing [BorderBeamTheme] instead.
///
/// State round-trips through the URL: the current configuration is written
/// to the address bar on the web, and the share button copies a link that
/// reproduces it.
class PlaygroundSection extends StatefulWidget {
  /// Const constructor.
  const PlaygroundSection({super.key});

  @override
  State<PlaygroundSection> createState() => _PlaygroundSectionState();
}

// The control column of the two-column layout: wide enough for a slider to
// keep its label, readout, and `auto` chip on one line.
const double _controlsWidth = 420;

// The install line above the playground.
const String _installCommand = 'flutter pub add flutter_border_beam';
const String _repoUrl = 'https://github.com/SimplifyJobs/flutter_border_beam';
const String _repoLabel = 'SimplifyJobs/flutter_border_beam';

class _PlaygroundSectionState extends State<PlaygroundSection> {
  late PlaygroundState _state = _initialState();

  // One controller per preview: a BorderBeamController may drive only one
  // beam at a time, and the wide layout shows two.
  final List<BorderBeamController> _controllers = [
    BorderBeamController(),
    BorderBeamController(),
  ];

  String? _copied;
  Timer? _copiedTimer;

  static PlaygroundState _initialState() {
    final encoded = playgroundStateStringFrom(Uri.base);
    return encoded == null ? PlaygroundState() : decodePlaygroundState(encoded);
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _edit(VoidCallback mutate) {
    setState(mutate);
    _publishState();
  }

  // On the web the address bar carries the configuration, so a reload — or a
  // copied URL — reproduces it.
  void _publishState() {
    if (!kIsWeb) return;
    final encoded = encodePlaygroundState(_state);
    SystemNavigator.routeInformationUpdated(
      uri: Uri(path: '/', query: encoded.isEmpty ? null : encoded),
      replace: true,
    );
  }

  void _controllerDo(void Function(BorderBeamController) action) {
    for (final controller in _controllers) {
      action(controller);
    }
  }

  void _setControllerMode(bool enabled) {
    _edit(() => _state.controllerMode = enabled);
  }

  void _copy(String label, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    setState(() => _copied = label);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  String _shareLink() {
    final encoded = encodePlaygroundState(_state);
    if (!kIsWeb) return playgroundShareUrl(encoded);
    final base = Uri.base;
    final page = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    ).toString();
    return encoded.isEmpty ? page : '$page#$encoded';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide enough for the controls to sit beside the preview instead of
        // above it.
        final wide = constraints.maxWidth >= 900;
        final previewWidth = wide
            ? constraints.maxWidth - _controlsWidth - 20
            : constraints.maxWidth;
        final previews = PlaygroundPreviews(
          state: _state,
          controllers: _controllers,
          // Both brightnesses fit beside each other once each half still
          // holds a readable surface.
          bothThemes: previewWidth >= 520,
        );
        final controls = ControlsPanel(
          state: _state,
          onEdit: _edit,
          onControllerMode: _setControllerMode,
          onControllerAction: _controllerDo,
        );
        final snippet = CodeBlock(
          code: buildSnippet(_state),
          copied: _copied == 'code',
          onCopy: () => _copy('code', buildSnippet(_state)),
        );

        final install = InstallBlock(
          command: _installCommand,
          repoLabel: _repoLabel,
          copied: _copied == 'install' || _copied == 'repo',
          onCopyCommand: () => _copy('install', _installCommand),
          onCopyRepo: () => _copy('repo', _repoUrl),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              install,
              const SizedBox(height: 12),
              _toolbar(),
              const SizedBox(height: 12),
              previews,
              const SizedBox(height: 16),
              controls,
              const SizedBox(height: 8),
              snippet,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            install,
            const SizedBox(height: 12),
            _toolbar(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _controlsWidth, child: controls),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [previews, const SizedBox(height: 16), snippet],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar() {
    final t = DemoTheme.of(context).tokens;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Every field the beam takes, live.',
            style: TextStyle(
              fontSize: 12,
              color: t.muted,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _copied == 'link' ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Text(
            'Copied',
            style: TextStyle(
              fontSize: 12,
              color: t.muted,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DemoChip(
          label: 'Copy share link',
          selected: false,
          onTap: () => _copy('link', _shareLink()),
        ),
        const SizedBox(width: 6),
        DemoChip(
          label: 'Reset',
          selected: false,
          onTap: () => _edit(() => _state = PlaygroundState()),
        ),
      ],
    );
  }
}
