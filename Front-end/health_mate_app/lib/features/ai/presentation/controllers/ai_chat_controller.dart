import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/ai_repository.dart';
import '../../domain/chat_message.dart';

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String sessionId;
  final String? error;
  final List<String>? _currentSymptoms;

  List<String> get currentSymptoms => _currentSymptoms ?? const [];

  AiChatState({
    required this.messages,
    this.isLoading = false,
    required this.sessionId,
    this.error,
    List<String>? currentSymptoms,
  }) : _currentSymptoms = currentSymptoms;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? sessionId,
    String? error,
    List<String>? currentSymptoms,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      error: error,
      currentSymptoms: currentSymptoms ?? _currentSymptoms,
    );
  }
}

class AiChatProviderArgs {
  final String locale;
  final String? initialSessionId;
  final String? initialContextMessage;

  const AiChatProviderArgs({
    required this.locale,
    this.initialSessionId,
    this.initialContextMessage,
  });

  @override
  bool operator ==(Object other) {
    return other is AiChatProviderArgs &&
        other.locale == locale &&
        other.initialSessionId == initialSessionId &&
        other.initialContextMessage == initialContextMessage;
  }

  @override
  int get hashCode => Object.hash(
        locale,
        initialSessionId,
        initialContextMessage,
      );
}

class AiChatController extends StateNotifier<AiChatState> {
  final AIRepository _repository;
  final String _locale;
  final String? _initialContextMessage;

  AiChatController(this._repository, AiChatProviderArgs args)
      : _locale = args.locale,
        _initialContextMessage = args.initialContextMessage,
        super(
          AiChatState(
            messages: [],
            sessionId: args.initialSessionId ?? const Uuid().v4(),
            currentSymptoms: [],
          ),
        ) {
    _sendInitialMessage();
  }

  void _sendInitialMessage() {
    final initialText = _initialContextMessage ??
        (_locale == 'ar'
            ? SymptomCheckerConstants.chatInitialMessageAr
            : SymptomCheckerConstants.chatInitialMessageEn);

    state = state.copyWith(
      messages: [
        ChatMessage(
          text: initialText,
          isUser: false,
          timestamp: DateTime.now(),
          type: 'text',
        ),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    final bool isInputArabic = _isArabic(text);
    final bool isInputEnglish = _isEnglish(text);
    final bool isAppArabic = _locale == 'ar';
    final bool isAppEnglish = _locale == 'en';

    bool mismatchDetected = false;
    String adviceText = '';

    if (isInputArabic && isAppEnglish) {
      mismatchDetected = true;
      adviceText =
          "I noticed you're typing in Arabic, but the app is currently in English. For better accuracy, would you like to switch to Arabic?";
    } else if (isInputEnglish && isAppArabic) {
      mismatchDetected = true;
      adviceText =
          'لاحظت أنك تكتب بالإنجليزية بينما التطبيق باللغة العربية. للحصول على نتائج أكثر دقة، هل تود تحويل لغة التطبيق إلى الإنجليزية؟';
    }

    if (mismatchDetected) {
      await Future.delayed(const Duration(milliseconds: 500));
      final languageAdvice = ChatMessage(
        text: adviceText,
        isUser: false,
        timestamp: DateTime.now(),
        type: 'language_switch',
      );

      state = state.copyWith(
        messages: [...state.messages, languageAdvice],
        isLoading: false,
      );
      return;
    }

    try {
      final response = await _repository.sendMessage(
        message: text,
        sessionId: state.sessionId,
        lang: _locale,
      );

      debugPrint('AI Response Raw: $response');

      final aiMessage = ChatMessage.fromJson(response);

      // Union with the previous list rather than replacing it outright.
      // The backend's `found_symptoms` is normally already the full
      // cumulative list for the session (chat_symptom_checker appends new
      // extractions server-side), but after a final diagnosis the server
      // resets its session state for the *next* cycle -- the very next
      // response can come back with a short/empty list even though the
      // conversation continues. Blindly replacing on that turn made
      // previously-mentioned symptoms disappear from the UI. Unioning never
      // loses a symptom the user already reported; `clearChat()` is the only
      // place currentSymptoms should ever actually shrink.
      final newSymptoms = aiMessage.foundSymptoms ?? const [];
      final mergedSymptoms = <String>{...state.currentSymptoms, ...newSymptoms}.toList();

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
        currentSymptoms: mergedSymptoms,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  bool _isArabic(String text) {
    return text.contains(RegExp(r'[\u0600-\u06FF]'));
  }

  bool _isEnglish(String text) {
    return text.contains(RegExp(r'[a-zA-Z]'));
  }

  void clearChat() {
    state = AiChatState(
      messages: [],
      sessionId: const Uuid().v4(),
      currentSymptoms: [],
    );
    _sendInitialMessage();
  }
}

final aiChatProvider = StateNotifierProvider.family<AiChatController,
    AiChatState, AiChatProviderArgs>((ref, args) {
  final repository = ref.watch(aiRepositoryProvider);
  return AiChatController(repository, args);
});
