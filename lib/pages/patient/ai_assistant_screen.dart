import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/orthoq_faq_knowledge.dart';
import '../../models/ai_assistant_quick_action.dart';
import '../../models/chat_message_model.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/chat_storage_service.dart';
import '../../services/gemini_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_typography.dart';
import 'specialist_recommendation_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatStorage = ChatStorageService();
  final _aiService = AiAssistantService();

  bool _isTyping = false;
  bool _isSending = false;
  String? _userId;

  static const _quickActions = [
    _QuickAction(
      label: 'Find Specialist',
      icon: Icons.psychology_outlined,
      action: AiAssistantQuickAction.findSpecialist,
      prompt: '',
    ),
    _QuickAction(
      label: 'Book Appointment',
      icon: Icons.calendar_month_rounded,
      action: AiAssistantQuickAction.bookAppointment,
      prompt: 'How do I book an appointment?',
    ),
    _QuickAction(
      label: 'Reschedule',
      icon: Icons.event_repeat_rounded,
      action: AiAssistantQuickAction.rescheduleAppointment,
      prompt: 'How do I reschedule my appointment?',
    ),
    _QuickAction(
      label: 'Upload Referral',
      icon: Icons.upload_file_rounded,
      action: AiAssistantQuickAction.uploadReferral,
      prompt: 'How do I upload a referral letter?',
    ),
    _QuickAction(
      label: 'View Appointment',
      icon: Icons.event_note_rounded,
      action: AiAssistantQuickAction.viewAppointment,
      prompt: 'When is my appointment?',
    ),
    _QuickAction(
      label: 'Contact Clinic',
      icon: Icons.call_rounded,
      action: AiAssistantQuickAction.contactClinic,
      prompt: 'How do I contact the clinic?',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAuthenticated());
  }

  void _ensureAuthenticated() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _userId = user.uid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    final userId = _userId;
    if (userId == null || _isSending) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _showSnack('Please enter a message before sending.');
      return;
    }

    setState(() {
      _isSending = true;
      _isTyping = true;
    });
    _messageController.clear();

    try {
      await _chatStorage.saveMessage(
        userId: userId,
        sender: ChatSender.user,
        message: trimmed,
      );

      final reply = await _aiService.getResponse(
        userId: userId,
        userMessage: trimmed,
      );

      await _chatStorage.saveMessage(
        userId: userId,
        sender: ChatSender.assistant,
        message: reply,
      );
    } on GeminiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Unable to send message. Please check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isTyping = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmDeleteHistory() async {
    final userId = _userId;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat history?'),
        content: const Text(
          'This will permanently remove all your messages with the AI assistant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _chatStorage.deleteAllForUser(userId);
      if (mounted) {
        _showSnack('Chat history deleted.');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Could not delete chat history. Please try again.');
      }
    }
  }

  Future<void> _handleQuickAction(_QuickAction action) async {
    if (action.action == AiAssistantQuickAction.findSpecialist) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const SpecialistRecommendationScreen(),
        ),
      );
      return;
    }

    if (action.action == AiAssistantQuickAction.contactClinic) {
      await _sendMessage(action.prompt);
      return;
    }

    if (action.prompt.isNotEmpty &&
        action.action != AiAssistantQuickAction.viewAppointment) {
      await _sendMessage(action.prompt);
      return;
    }

    if (action.action == AiAssistantQuickAction.viewAppointment) {
      await _sendMessage('When is my appointment?');
      return;
    }

    if (mounted) {
      Navigator.pop(context, action.action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: OrthoqTypography.sectionTitle(color: Colors.white)),
                Text(
                  'OrthoQ · Hospital Kajang',
                  style: OrthoqTypography.bodySmall(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Symptom-based specialist recommendation',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const SpecialistRecommendationScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete chat history',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: userId == null ? null : _confirmDeleteHistory,
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessageModel>>(
                    stream: _chatStorage.watchMessages(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Unable to load chat history. Check your connection.',
                              textAlign: TextAlign.center,
                              style: OrthoqTypography.bodyMedium(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];
                      _scrollToBottom();

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.isEmpty
                            ? 2
                            : messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (messages.isEmpty && index == 0) {
                            return _WelcomeBanner(
                              message: OrthoqFaqKnowledge.welcomeHint,
                            );
                          }

                          if (messages.isEmpty && index == 1) {
                            return _isTyping
                                ? const _TypingIndicatorBubble()
                                : const SizedBox.shrink();
                          }

                          if (index < messages.length) {
                            return _MessageBubble(message: messages[index]);
                          }

                          return const _TypingIndicatorBubble();
                        },
                      );
                    },
                  ),
                ),
                _QuickActionsBar(
                  actions: _quickActions,
                  onTap: _isSending ? null : _handleQuickAction,
                ),
                _MessageInputBar(
                  controller: _messageController,
                  isSending: _isSending,
                  onSend: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.action,
    required this.prompt,
  });

  final String label;
  final IconData icon;
  final AiAssistantQuickAction action;
  final String prompt;
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OrthoqColors.navy.withValues(alpha: 0.08),
            OrthoqColors.logoAccent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrthoqColors.navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OrthoqColors.navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: OrthoqColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: OrthoqTypography.bodyMedium()),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeLabel = DateFormat('h:mm a').format(message.timestamp);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? OrthoqColors.navy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: OrthoqTypography.bodyMedium(
                color: isUser ? Colors.white : OrthoqColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: OrthoqTypography.bodySmall(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.75)
                    : OrthoqColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final delay = index * 0.2;
                final value = (_controller.value + delay) % 1.0;
                final opacity = value < 0.5 ? 0.3 + value : 1.1 - value;
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: OrthoqColors.navy.withValues(alpha: opacity.clamp(0.3, 1.0)),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    required this.actions,
    required this.onTap,
  });

  final List<_QuickAction> actions;
  final Future<void> Function(_QuickAction action)? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = actions[index];
          return ActionChip(
            avatar: Icon(action.icon, size: 16, color: OrthoqColors.navy),
            label: Text(action.label),
            labelStyle: OrthoqTypography.bodySmall(color: OrthoqColors.navy),
            backgroundColor: Colors.white,
            side: BorderSide(color: OrthoqColors.navy.withValues(alpha: 0.15)),
            onPressed: onTap == null ? null : () => onTap!(action),
          );
        },
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about appointments, referrals…',
                  filled: true,
                  fillColor: OrthoqColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: OrthoqColors.navy,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: isSending ? null : onSend,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: isSending
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the AI assistant and returns an optional [AiAssistantQuickAction]
/// for tab navigation in [PatientHomeScreen].
Future<AiAssistantQuickAction?> openAiAssistant(BuildContext context) {
  return Navigator.of(context).push<AiAssistantQuickAction>(
    MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
  );
}

int tabIndexForQuickAction(AiAssistantQuickAction action) {
  switch (action) {
    case AiAssistantQuickAction.bookAppointment:
    case AiAssistantQuickAction.uploadReferral:
      return 1;
    case AiAssistantQuickAction.rescheduleAppointment:
    case AiAssistantQuickAction.viewAppointment:
      return 2;
    case AiAssistantQuickAction.contactClinic:
    case AiAssistantQuickAction.findSpecialist:
      return 0;
  }
}
