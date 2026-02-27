import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';

class ChatbotFab extends StatelessWidget {
  const ChatbotFab({
    super.key,
    required this.heroTag,
  });

  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: 'AI Chatbot',
      onPressed: () => Navigator.pushNamed(context, MyApp.routeChatbot),
      child: const Icon(Icons.smart_toy_outlined),
    );
  }
}
