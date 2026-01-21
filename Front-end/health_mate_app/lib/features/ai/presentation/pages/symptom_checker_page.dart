import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/ai_repository.dart';
import '../../domain/chat_message.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class SymptomCheckerPage extends ConsumerStatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  ConsumerState<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends ConsumerState<SymptomCheckerPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    _messages.add(
      ChatMessage(
        text: LocaleKeys.aiWelcomeMessage.tr(),
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await ref
          .read(aiRepositoryProvider)
          .sendMessage(message: text, sessionId: _sessionId);

      if (response['session_id'] != null) {
        _sessionId = response['session_id'];
      }

      final aiText = response['message'] ?? LocaleKeys.aiUnknownResponse.tr();
      final options = response['options'] != null
          ? List<String>.from(response['options'])
          : null;

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: aiText,
              isUser: false,
              timestamp: DateTime.now(),
              options: options,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: LocaleKeys.aiErrorMessage.tr(),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.homeAiChat.tr(),
      ),
      body: Container(
        padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(context.w(4)),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(4), vertical: context.h(1)),
                child: const LinearProgressIndicator(),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: context.h(0.5)),
        padding: EdgeInsets.symmetric(
            horizontal: context.w(4), vertical: context.h(1.2)),
        constraints: BoxConstraints(
          maxWidth: context.w(75),
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primary
              : (isDark ? AppColors.cardDark : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(context.sp(16)),
            topRight: Radius.circular(context.sp(16)),
            bottomLeft: Radius.circular(message.isUser ? context.sp(16) : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : context.sp(16)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: context.sp(15),
                color: message.isUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (message.options != null && message.options!.isNotEmpty) ...[
              SizedBox(height: context.h(1)),
              Wrap(
                spacing: context.w(2),
                runSpacing: context.h(0.5),
                children: message.options!.map((option) {
                  return ActionChip(
                    label: Text(option),
                    padding: EdgeInsets.symmetric(
                        horizontal: context.w(2), vertical: context.h(0.5)),
                    onPressed: () => _sendMessage(option),
                    backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    labelStyle: TextStyle(
                      color: AppColors.primary,
                      fontSize: context.sp(12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(context.w(4), context.h(1), context.w(2),
          context.h(1) + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                  fontSize: context.sp(16),
                  color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: LocaleKeys.aiInputPlaceholder.tr(),
                hintStyle:
                    TextStyle(fontSize: context.sp(16), color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: context.w(2)),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send,
                color: AppColors.primary, size: context.sp(24)),
            onPressed: () => _sendMessage(_controller.text),
          ),
        ],
      ),
    );
  }
}
