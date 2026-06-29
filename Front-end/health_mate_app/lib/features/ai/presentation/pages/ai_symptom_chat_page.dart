import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/expert_app_bar.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../controllers/ai_chat_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AiSymptomChatPage extends ConsumerStatefulWidget {
  const AiSymptomChatPage({super.key});

  @override
  ConsumerState<AiSymptomChatPage> createState() => _AiSymptomChatPageState();
}

class _AiSymptomChatPageState extends ConsumerState<AiSymptomChatPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final chatState = ref.watch(aiChatProvider(currentLocale));
    final chatController = ref.read(aiChatProvider(currentLocale).notifier);

    // Auto scroll to bottom when new messages arrive
    ref.listen(aiChatProvider(currentLocale), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0a0e14)
          : const Color(0xFFF8FBFC),
      appBar: ExpertAppBar(
        title: LocaleKeys.homeAiChat.tr(),
        onBackTap: () {
          // Expert Back Logic:
          // 1. If we can pop the navigator (pushed page), do it.
          // 2. If we are in the bottom nav, switch to Home tab.
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            ref.read(navigationProvider.notifier).goHome();
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _showResetConfirmation(context, chatController),
            tooltip: LocaleKeys.refresh.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDisclaimer(),
          Expanded(
            child: Stack(
              children: [
                chatState.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          top: context.h(1),
                          bottom: context.h(2),
                        ),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final authState = ref.watch(authNotifierProvider);
                          return ChatBubble(
                            message: chatState.messages[index],
                            userProfileImage: authState.user?.profileImage,
                          );
                        },
                      ),
                if (chatState.isLoading)
                  Positioned(
                    bottom: context.h(1),
                    left: 0,
                    right: 0,
                    child: _buildTypingIndicator(),
                  ),
              ],
            ),
          ),

          // Expert Bottom Section (Tags + Suggestions + Input)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0a0e14)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Detected Symptoms Tags
                  if (chatState.currentSymptoms.isNotEmpty)
                    _buildSymptomsTags(chatState),

                  // 2. Quick Replies / Suggestions
                  if (chatState.messages.isNotEmpty &&
                      !chatState.messages.last.isUser &&
                      chatState.messages.last.options != null)
                    _buildQuickReplies(
                        chatState.messages.last.options!, chatController),

                  // 3. Main Input Field
                  ChatInputField(
                    isLoading: chatState.isLoading,
                    onSend: (text) => chatController.sendMessage(text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomsTags(AiChatState chatState) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: context.w(4), vertical: context.h(1)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.02),
        border: Border(
            bottom:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                EdgeInsets.only(left: context.w(1), bottom: context.h(0.5)),
            child: Text(
              context.locale.languageCode == 'ar'
                  ? "الأعراض المكتشفة:"
                  : "Detected Symptoms:",
              style: TextStyle(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w800,
                color: AppColors.primary.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: chatState.currentSymptoms.map((symptom) {
                return Container(
                  margin: EdgeInsets.only(right: context.w(2.5)),
                  child: Chip(
                    label: Text(
                      symptom,
                      style: TextStyle(
                        fontSize: context.sp(10.5),
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.symmetric(
                        horizontal: context.w(2), vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    final isAr = context.locale.languageCode == 'ar';
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.w(3)),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: AppColors.error.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.gpp_maybe_rounded, color: AppColors.error, size: 20),
              SizedBox(width: context.w(2)),
              Expanded(
                child: Text(
                  isAr
                      ? SymptomCheckerConstants.chatDisclaimerAr
                      : SymptomCheckerConstants.chatDisclaimerEn,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 1),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(context.w(6)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_rounded,
                size: context.w(20),
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            SizedBox(height: context.h(3)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(10)),
              child: Text(
                LocaleKeys.aiWelcomeMessage.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: context.sp(16),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.w(6)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: context.w(4), vertical: context.h(1)),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: List.generate(3, (index) {
                return _TypingDot(delay: index * 200);
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(
      BuildContext context, AiChatController controller) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            LocaleKeys.refresh.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            context.locale.languageCode == 'ar'
                ? "هل أنت متأكد من أنك تريد مسح سجل المحادثة؟"
                : "Are you sure you want to clear the chat history?",
            style: TextStyle(fontSize: context.sp(14)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.cancel.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                controller.clearChat();
                Navigator.pop(context);
              },
              child: Text(LocaleKeys.confirm.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplies(List<String> options, AiChatController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = context.locale.languageCode == 'ar';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clampedValue = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - clampedValue)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.h(1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(5), vertical: context.h(0.5)),
              child: Text(
                isAr
                    ? SymptomCheckerConstants.suggestionsAr
                    : SymptomCheckerConstants.suggestionsEn,
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  fontSize: context.sp(10),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: context.h(5.5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.w(4)),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: context.w(2)),
                    child: InkWell(
                      onTap: () => controller.sendMessage(options[index]),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.w(4), vertical: context.h(1)),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              options[index] == "نعم" || options[index] == "Yes"
                                  ? Icons.check_circle_rounded
                                  : (options[index].contains("لا") ||
                                          options[index].contains("No")
                                      ? Icons.stop_circle_outlined
                                      : Icons.check_circle_outline_rounded),
                              size: 16,
                              color:
                                  isDark ? Colors.white70 : AppColors.primary,
                            ),
                            SizedBox(width: context.w(2)),
                            Text(
                              (options[index] == "نعم" ||
                                      options[index] == "Yes" ||
                                      options[index].contains("لا") ||
                                      options[index].contains("No"))
                                  ? options[index]
                                  : (isAr
                                      ? "أعاني من ${options[index]}"
                                      : "I have ${options[index]}"),
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white : AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: context.sp(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(alpha: 0.3 + (0.7 * _animation.value)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
