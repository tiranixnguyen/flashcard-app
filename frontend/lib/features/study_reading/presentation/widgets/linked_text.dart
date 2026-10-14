import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/platform/link_launcher.dart";
import "../../domain/linkify.dart";

/// Chữ thuần có link `http(s)://` bấm được — mở bằng trình duyệt của máy.
/// Chỉ dùng trên Mac/web.
class LinkedText extends ConsumerStatefulWidget {
  const LinkedText(
    this.text, {
    super.key,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;

  @override
  ConsumerState<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends ConsumerState<LinkedText> {
  List<TextSegment> _segments = const [];
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(LinkedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _build();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Mỗi link một recognizer, giữ trong State để dispose đúng lúc.
  void _build() {
    _disposeRecognizers();
    _segments = linkify(widget.text);
    for (final s in _segments) {
      if (s.link case final uri?) {
        _recognizers.add(TapGestureRecognizer()..onTap = () => _open(uri));
      }
    }
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await ref.read(linkLauncherProvider).open(uri);
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text("Không mở được $uri")));
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final s in _segments)
            s.link == null
                ? TextSpan(text: s.text)
                : TextSpan(
                    text: s.text,
                    recognizer: _recognizers[i++],
                    mouseCursor: SystemMouseCursors.click,
                    style: TextStyle(
                      color: widget.linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: widget.linkColor,
                    ),
                  ),
        ],
      ),
    );
  }
}
