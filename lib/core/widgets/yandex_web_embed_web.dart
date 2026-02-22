import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

typedef WebMapMessageHandler = void Function(Map<String, dynamic> message);

class YandexWebIFrame extends StatefulWidget {
  const YandexWebIFrame({
    super.key,
    required this.html,
    this.onMessage,
  });

  final String html;
  final WebMapMessageHandler? onMessage;

  @override
  State<YandexWebIFrame> createState() => _YandexWebIFrameState();
}

class _YandexWebIFrameState extends State<YandexWebIFrame> {
  late String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _msgSub;

  @override
  void initState() {
    super.initState();
    _registerView();
    _msgSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;
      final type = data['type'];
      if (type is! String) return;
      final normalized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key;
        if (key is String) normalized[key] = entry.value;
      }
      widget.onMessage?.call(normalized);
    });
  }

  @override
  void didUpdateWidget(covariant YandexWebIFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _iframe?.srcdoc = widget.html;
      _iframe?.src = _toDataUri(widget.html);
    }
  }

  String _toDataUri(String content) {
    return 'data:text/html;charset=utf-8,${Uri.encodeComponent(content)}';
  }

  void _registerView() {
    _viewType = 'yandex-map-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..srcdoc = widget.html
        ..src = _toDataUri(widget.html)
        ..allow = 'geolocation *; fullscreen *';
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _iframe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
