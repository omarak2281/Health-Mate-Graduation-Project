import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../ai/presentation/pages/symptom_checker_page.dart';
import '../../../medications/presentation/pages/medications_page.dart';
import '../../../../core/services/socket_service.dart';
import '../../../communication/presentation/pages/incoming_call_page.dart';
import '../widgets/patient_dashboard_widgets.dart';
import '../widgets/patient_graphs.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';

/// Patient Home Page
/// Professional dashboard with BP monitoring, heart rate, and measurements history
/// Designed to match expert healthcare UI standards

class PatientHomePage extends ConsumerStatefulWidget {
  const PatientHomePage({super.key});

  @override
  ConsumerState<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends ConsumerState<PatientHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize Socket Service for Incoming Calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = ref.read(socketServiceProvider);

      socketService.onCallOffer((data) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallPage(
              callerName: data['callerName'] ?? 'Contact',
              callerId: data['callerId'],
              isVideo: data['isVideo'] ?? false,
            ),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(2),
            vertical: context.h(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: AppIcons.home,
                label: LocaleKeys.homeHome.tr(),
              ),
              _buildNavItem(
                index: 1,
                icon: AppIcons.check,
                label: LocaleKeys.homeCheck.tr(),
              ),
              _buildNavItem(
                index: 2,
                icon: AppIcons.pill,
                label: LocaleKeys.homeMeds.tr(),
              ),
              _buildNavItem(
                index: 3,
                icon: ({size, color}) =>
                    Icon(Icons.contacts_outlined, size: size, color: color),
                label: LocaleKeys.contacts.tr(),
              ),
              _buildNavItem(
                index: 4,
                icon: AppIcons.settings,
                label: LocaleKeys.homeSetting.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required Widget Function({double? size, Color? color}) icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: context.w(1),
            vertical: context.h(0.6),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isSelected ? 1.1 : 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: icon(
                      size: context.sp(24),
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white60 : AppColors.textSecondary),
                    ),
                  );
                },
              ),
              SizedBox(height: context.h(0.2)),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.sp(9),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white60 : AppColors.textSecondary),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const SymptomCheckerPage();
      case 2:
        return const MedicationsPage();
      case 3:
        return const MedicalContactsPage(); // 4th item: Contacts
      case 4:
        return const SettingsPage(); // 5th item: Settings
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = ref.watch(authNotifierProvider).user;

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh vitals data when model is ready
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header with Gradient Background
            _buildUserHeader(user),
            SizedBox(height: context.h(2)),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(5)),
              child: Column(
                children: [
                  // Heart Rate Card
                  HeartRateCard(
                    heartRate: null, // Will be populated from model
                    avgToday: null,
                    maxToday: null,
                  ),
                  SizedBox(height: context.h(2.5)),

                  // Blood Pressure Card
                  BloodPressureCardExpert(
                    systolic: null, // Will be populated from model
                    diastolic: null,
                    time: null,
                    onCheckNow: () {
                      // TODO: Navigate to BP checking page
                    },
                  ),
                  SizedBox(height: context.h(2.5)),

                  // BP Trend Graph
                  const BloodPressureTrendCard(),
                  SizedBox(height: context.h(2.5)),

                  // Measurements History Card
                  MeasurementsHistoryCard(
                    onTap: () {
                      // TODO: Navigate to measurements history page
                    },
                  ),
                  SizedBox(height: context.h(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(user) {
    // Extract first name from full name
    final firstName =
        user?.fullName?.split(' ').first ?? LocaleKeys.commonHello.tr();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: context.w(5),
        right: context.w(5),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: context.sp(48),
            height: context.sp(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: user?.profileImage != null
                  ? Image.network(
                      user!.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: context.sp(24),
                        );
                      },
                    )
                  : Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: context.sp(24),
                      ),
                    ),
            ),
          ),
          SizedBox(width: context.w(4)),

          // Greeting Text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.commonHello.tr(),
                style: TextStyle(
                  fontSize: context.sp(14),
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                firstName,
                style: TextStyle(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
