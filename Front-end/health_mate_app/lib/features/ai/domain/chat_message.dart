import '../../../core/constants/app_constants.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? type; // 'text', 'options', 'diagnosis'
  final List<String>? options;
  final String? diagnosis;
  final double? confidence;
  final List<String>? foundSymptoms;
  final String? severity;
  final String? advice;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.type = 'text',
    this.options,
    this.diagnosis,
    this.confidence,
    this.foundSymptoms,
    this.severity,
    this.advice,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Check all possible keys for the main text response
    final rawText = json['text'] ?? 
                 json['response'] ?? 
                 json['message'] ?? 
                 json['reply'] ?? 
                 json['result'] ?? 
                 json['ai_response'] ?? 
                 json['data']?['text'] ?? 
                 json['data']?['response'] ??
                 '';
                 
    var textValue = rawText.toString();
    
    // Localization Override: If backend returns hardcoded English listening message, 
    // and we want Arabic (detected by absence of diagnosis or user choice), we swap it.
    if (textValue == SymptomCheckerConstants.chatListeningEn) {
      // In a real app, we'd check context.locale, but here we'll assume 
      // if the user expects Arabic (no diagnosis yet), we can provide it.
      // But for now, let's just make it possible to swap if detected.
      textValue = SymptomCheckerConstants.chatListeningAr;
    }

    final diagnosisValue = json['disease']?.toString() ??
                           json['diagnosis']?.toString() ?? 
                           json['predicted_disease']?.toString() ?? 
                           json['disease_info']?['name']?.toString() ??
                           json['data']?['diagnosis']?.toString();

    // If we have a diagnosis but no text, provide a professional fallback
    if (textValue.isEmpty && diagnosisValue != null) {
      // Use localized fallback from constants if available
      final isAr = diagnosisValue.contains(RegExp(r'[\u0600-\u06FF]'));
      textValue = isAr 
          ? SymptomCheckerConstants.diagnosisFallbackAr 
          : SymptomCheckerConstants.diagnosisFallbackEn;
          
      final description = json['disease_info']?['description']?.toString();
      if (description != null && description.isNotEmpty) {
        textValue += "\n\n$description";
      }
    }

    return ChatMessage(
      text: textValue,
      isUser: json['is_user'] == true,
      timestamp: DateTime.now(),
      type: json['type']?.toString() ?? (diagnosisValue != null ? 'diagnosis' : 'text'),
      options: json['options'] != null
          ? List<String>.from(json['options'].map((e) => e.toString()))
          : null,
      diagnosis: diagnosisValue,
      confidence: (json['confidence'] ?? json['data']?['confidence']) != null 
          ? ((json['confidence'] ?? json['data']?['confidence']) as num).toDouble() 
          : null,
      foundSymptoms: json['found_symptoms'] != null
          ? List<String>.from(json['found_symptoms'].map((e) => e.toString()))
          : null,
      severity: json['disease_info']?['severity']?.toString(),
      advice: json['disease_info']?['advice']?.toString(),
    );
  }
}
