import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String? userProfileImage;

  const ChatBubble({
    super.key,
    required this.message,
    this.userProfileImage,
  });

  /// The backend's final-diagnosis message packs disease name + advice +
  /// disclaimer into one `\n\n`-joined string (see `generate_final_diagnosis`
  /// in ai.py) -- but the name/advice are ALSO rendered, styled, in
  /// [_buildDiagnosisCard]. Showing the raw text in full underneath the card
  /// duplicated that content (and left literal `**` markers visible, since
  /// this is plain Text with no markdown renderer). When a diagnosis card is
  /// shown, keep only the last paragraph (the disclaimer); otherwise show
  /// the text as-is, with markdown bold markers stripped.
  String get _displayText {
    final stripped = message.text.replaceAll('**', '');
    if (message.diagnosis == null) return stripped;
    final paragraphs = stripped.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    return paragraphs.isNotEmpty ? paragraphs.last.trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.h(SymptomCheckerConstants.spacingSmall),
        horizontal: context.w(SymptomCheckerConstants.paddingMedium),
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _buildAvatar(context),
              SizedBox(width: context.w(2)),
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(context.w(3)),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : (isDark ? AppColors.surfaceDark : Colors.white),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomLeft:
                          isUser ? const Radius.circular(20) : Radius.zero,
                      bottomRight:
                          isUser ? Radius.zero : const Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.1)
                          : (isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05)),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.type == 'language_switch') ...[
                        _buildLanguageSwitchButton(context),
                        SizedBox(height: context.h(1)),
                      ],
                      if (message.type == 'diagnosis' ||
                          message.diagnosis != null) ...[
                        _buildDiagnosisCard(context),
                        SizedBox(height: context.h(1)),
                      ],
                      if (_displayText.isNotEmpty)
                        Text(
                          _displayText,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontSize: context.sp(14),
                            height: 1.5,
                            fontWeight:
                                isUser ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: context.w(2)),
              if (isUser) _buildUserAvatar(context),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: context.h(0.5),
              left: isUser ? 0 : context.w(12),
              right: isUser ? context.w(12) : 0,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: context.sp(SymptomCheckerConstants.fontSizeSmall),
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: context.w(10),
      height: context.w(10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.medical_services_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Bidi.isRtlLanguage(context.locale.languageCode);

    return Container(
      margin: EdgeInsets.only(bottom: context.h(1)),
      padding: EdgeInsets.all(context.w(3)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isAr ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isAr) ...[
                Icon(Icons.health_and_safety_rounded,
                    color: AppColors.primary, size: 20),
                SizedBox(width: context.w(2)),
              ],
              Text(
                isAr ? "التشخيص المحتمل" : "Potential Diagnosis",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.sp(14),
                  color: AppColors.primary,
                ),
              ),
              if (isAr) ...[
                SizedBox(width: context.w(2)),
                Icon(Icons.health_and_safety_rounded,
                    color: AppColors.primary, size: 20),
              ],
            ],
          ),
          SizedBox(height: context.h(1)),
          Text(
            message.diagnosis!,
            textAlign: isAr ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.sp(18),
              color: isDark ? Colors.white : AppColors.primaryDark,
              letterSpacing: isAr ? 0 : 0.5,
            ),
          ),
          if (message.confidence != null) ...[
            SizedBox(height: context.h(1.5)),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: message.confidence,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  message.confidence! > 0.7
                      ? Colors.green
                      : (message.confidence! > 0.4
                          ? Colors.orange
                          : Colors.red),
                ),
                minHeight: 8,
              ),
            ),
          ],
          if (message.severity != null) ...[
            SizedBox(height: context.h(1.5)),
            _buildSeverityBadge(context, message.severity!),
          ],
          if (message.advice != null) ...[
            SizedBox(height: context.h(1.5)),
            _buildAdviceSection(context, message.advice!),
          ],
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(BuildContext context, String severity) {
    final isAr = Bidi.isRtlLanguage(context.locale.languageCode);
    Color badgeColor;
    IconData icon;

    if (severity.contains("خطيرة") || severity.contains("High")) {
      badgeColor = Colors.red;
      icon = Icons.warning_rounded;
    } else if (severity.contains("متوسطة") || severity.contains("Moderate")) {
      badgeColor = Colors.orange;
      icon = Icons.info_rounded;
    } else {
      badgeColor = Colors.green;
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(3), vertical: context.h(0.5)),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 16),
          SizedBox(width: context.w(2)),
          Text(
            "${isAr ? "الشدة: " : "Severity: "}$severity",
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: context.sp(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceSection(BuildContext context, String advice) {
    final isAr = Bidi.isRtlLanguage(context.locale.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(context.w(3)),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
          SizedBox(width: context.w(2)),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? "نصيحة طبية:" : "Medical Advice:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.sp(12),
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: context.h(0.5)),
                Text(
                  advice,
                  textAlign: isAr ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: context.sp(12),
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Container(
      width: context.w(10),
      height: context.w(10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: userProfileImage != null
            ? Image.network(
                userProfileImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultUserIcon(),
              )
            : _buildDefaultUserIcon(),
      ),
    );
  }

  Widget _buildDefaultUserIcon() {
    return const Icon(
      Icons.person_rounded,
      color: Colors.white,
      size: 20,
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildLanguageSwitchButton(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    return Container(
      margin: EdgeInsets.only(top: context.h(1)),
      child: ElevatedButton.icon(
        onPressed: () {
          context.setLocale(isAr ? const Locale('en') : const Locale('ar'));
        },
        icon: const Icon(Icons.translate_rounded, size: 18),
        label: Text(isAr
            ? "Switch to English / الإنجليزية"
            : "Switch to Arabic / العربية"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: context.w(4), vertical: context.h(1)),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
