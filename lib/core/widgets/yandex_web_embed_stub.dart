import 'package:flutter/widgets.dart';

typedef WebMapMessageHandler = void Function(Map<String, dynamic> message);

class YandexWebIFrame extends StatelessWidget {
  const YandexWebIFrame({
    super.key,
    required this.html,
    this.onMessage,
  });

  final String html;
  final WebMapMessageHandler? onMessage;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
