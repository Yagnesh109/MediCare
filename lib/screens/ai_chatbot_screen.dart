import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicare_app/services/medical_chat_service.dart';

class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      role: _ChatRole.bot,
      text:
          'Hi, I am your AI medical assistant. Share your prescription or ask about medicine use, health, food, diet, and exercise.',
    ),
  ];

  bool _isSending = false;
  String _prescriptionImageBase64 = '';
  String _prescriptionImageMimeType = '';
  String _prescriptionImageLabel = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickPrescriptionImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose From Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);
    final lower = picked.path.toLowerCase();
    final mimeType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
    final label = picked.path.split(RegExp(r'[\\/]')).last;

    if (!mounted) return;
    setState(() {
      _prescriptionImageBase64 = base64Image;
      _prescriptionImageMimeType = mimeType;
      _prescriptionImageLabel = label;
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(role: _ChatRole.user, text: text));
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.role != _ChatRole.system)
          .take(12)
          .map((m) => '${m.role == _ChatRole.user ? 'User' : 'Assistant'}: ${m.text}')
          .toList();

      final result = await MedicalChatService.instance.chat(
        MedicalChatRequest(
          userMessage: text,
          prescriptionImageBase64: _prescriptionImageBase64,
          prescriptionImageMimeType: _prescriptionImageMimeType,
          history: history,
        ),
      );
      final reply = _formatReply(result);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          role: _ChatRole.bot,
          text: reply,
          emergency: result.emergency,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.system,
            text: 'Unable to get AI response right now: $e',
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatReply(MedicalChatResult result) {
    final buffer = StringBuffer();
    final mainReply = result.reply.trim();
    if (mainReply.isNotEmpty) {
      buffer.writeln(mainReply);
    }

    void addSection(String title, List<String> values) {
      if (values.isEmpty) return;
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln(title);
      for (final value in values) {
        buffer.writeln('- $value');
      }
    }

    addSection('Medicine Uses', result.medicineUses);
    addSection('Health Guidance', result.healthGuidance);
    addSection('Diet Guidance', result.dietGuidance);
    addSection('Exercise Guidance', result.exerciseGuidance);
    addSection('Precautions', result.precautions);

    return buffer.toString().trim();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Specialist Chatbot'),
      ),
      body: Column(
        children: [
          if (_prescriptionImageLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Prescription: $_prescriptionImageLabel',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == _ChatRole.user;
                final isSystem = message.role == _ChatRole.system;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: isSystem
                          ? const Color(0xFFFFF3E0)
                          : isUser
                              ? const Color(0xFF2E84F3)
                              : message.emergency
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFE9F2FF),
                      borderRadius: BorderRadius.circular(14),
                      border: message.emergency
                          ? Border.all(color: const Color(0xFFD32F2F))
                          : null,
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF111827),
                        height: 1.3,
                        fontWeight: message.emergency ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _prescriptionImageBase64.isEmpty
                        ? 'Upload prescription image'
                        : 'Change prescription image',
                    onPressed: _pickPrescriptionImage,
                    icon: Icon(
                      _prescriptionImageBase64.isEmpty
                          ? Icons.upload_file_outlined
                          : Icons.image_outlined,
                    ),
                  ),
                  if (_prescriptionImageBase64.isNotEmpty)
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: () {
                        setState(() {
                          _prescriptionImageBase64 = '';
                          _prescriptionImageMimeType = '';
                          _prescriptionImageLabel = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about medicines, diet, exercise...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatRole {
  user,
  bot,
  system,
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.emergency = false,
  });

  final _ChatRole role;
  final String text;
  final bool emergency;
}
