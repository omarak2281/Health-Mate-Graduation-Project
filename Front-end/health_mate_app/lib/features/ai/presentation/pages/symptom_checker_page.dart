import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/professional_error_handler.dart';
import '../../../../core/services/error_handling_service.dart';
import '../../data/ai_repository.dart';
import '../../services/model_data_service.dart';
import '../../../../core/widgets/expert_app_bar.dart';

enum SymptomCheckerStep {
  specialty,
  symptoms,
  results,
}

class SymptomCheckerData {
  String category = 'General';
  String subCategory = '';
  List<String> selectedSymptoms = [];
  Map<String, dynamic>? analysisResult;
  Map<String, dynamic>? categoriesData;

  // Validation methods
  bool get isValidSelection => selectedSymptoms.isNotEmpty;
  int get selectedSymptomsCount => selectedSymptoms.length;

  void clearSelection() {
    selectedSymptoms.clear();
  }

  void addSymptom(String symptomId) {
    if (!selectedSymptoms.contains(symptomId)) {
      selectedSymptoms.add(symptomId);
    }
  }

  void removeSymptom(String symptomId) {
    selectedSymptoms.remove(symptomId);
  }
}

class SymptomCheckerPage extends ConsumerStatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  ConsumerState<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends ConsumerState<SymptomCheckerPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  SymptomCheckerStep _currentStep = SymptomCheckerStep.specialty;
  final SymptomCheckerData _data = SymptomCheckerData();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadInitialData();
    _preloadModelInfo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _preloadModelInfo() async {
    try {
      await ref.read(modelDataServiceProvider).loadModelInfo();
    } catch (e) {
      // Model loading error is handled in the service
      debugPrint('Model info preloading failed: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final repository = ref.read(aiRepositoryProvider);
      final categories = await repository.getAvailableSymptoms();

      setState(() {
        _data.categoriesData = categories;
        _isLoading = false;
        // Ensure subCategory is set to a valid default
        _ensureValidSubCategory();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ProfessionalErrorHandler.showErrorDialog(
          context: context,
          titleKey: LocaleKeys.symptomCheckerErrorLoading.tr(),
          messageKey: LocaleKeys.symptomCheckerErrorLoading.tr(),
          subtitleKey: LocaleKeys.symptomCheckerTip.tr(),
          showRetry: true,
          onRetry: _loadInitialData,
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep.index < SymptomCheckerStep.values.length - 1) {
      setState(() {
        _currentStep = SymptomCheckerStep.values[_currentStep.index + 1];
      });
      _pageController.animateToPage(
        _currentStep.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.forward().then((_) {
        _animationController.reset();
      });
    }
  }

  void _previousStep() {
    if (_currentStep.index > 0) {
      setState(() {
        _currentStep = SymptomCheckerStep.values[_currentStep.index - 1];
      });
      _pageController.animateToPage(
        _currentStep.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _ensureValidSubCategory() {
    final mapping = _data.categoriesData?[SymptomCheckerConstants.keyMapping]
        as Map<String, dynamic>?;
    if (mapping == null) return;

    final categoryList = mapping[_data.category] as List<dynamic>?;
    if (categoryList == null || categoryList.isEmpty) {
      // Set defaults based on category
      _data.subCategory =
          _data.category == SymptomCheckerConstants.categoryHeart
              ? SymptomCheckerConstants.defaultHeartSubCategory
              : SymptomCheckerConstants.defaultGeneralSubCategory;
      return;
    }

    // Check if current subCategory is valid
    final validValues = categoryList.map((e) => e.toString()).toList();
    if (_data.subCategory.isEmpty || !validValues.contains(_data.subCategory)) {
      _data.subCategory = validValues.first;
    }
  }

  void _goToStep(SymptomCheckerStep step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step.index,
      duration: SymptomCheckerConstants.pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0a0e14)
          : const Color(0xFFF8FBFC),
      appBar: ExpertAppBar(
        title: LocaleKeys.homeAiChat.tr(),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildContent(isSmallScreen, isTablet),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: context.h(2)),
          Text(
            LocaleKeys.symptomCheckerLoadingData.tr(),
            style: TextStyle(
              fontSize: context.sp(16),
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isSmallScreen, bool isTablet) {
    if (_error != null) {
      return _buildErrorState();
    }

    if (isSmallScreen) {
      return _buildMobileLayout();
    } else if (isTablet) {
      return _buildTabletLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Container(
      padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
      child: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSpecialtyPage(),
                _buildSymptomsPage(),
                _buildResultsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Container(
      padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
      child: Row(
        children: [
          // Left sidebar with navigation
          SizedBox(
            width: context.w(25),
            child: _buildSidebarNavigation(),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: ClipRect(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildSpecialtyPage(),
                        _buildSymptomsPage(),
                        _buildResultsPage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
      child: Row(
        children: [
          // Left sidebar with navigation
          SizedBox(
            width: context.w(20),
            child: _buildSidebarNavigation(),
          ),
          // Main content with more space
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: ClipRect(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildSpecialtyPage(),
                        _buildSymptomsPage(),
                        _buildResultsPage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({String? message, VoidCallback? onRetry}) {
    final errorMessage =
        message ?? _error ?? LocaleKeys.symptomCheckerUnknownError.tr();
    final retryAction = onRetry ?? _loadInitialData;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.w(4)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: context.w(20),
              color: AppColors.error,
            ),
            SizedBox(height: context.h(2)),
            Text(
              LocaleKeys.symptomCheckerErrorLoading.tr(),
              style: TextStyle(
                fontSize: context.sp(18),
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            SizedBox(height: context.h(1)),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.sp(14),
                color: Colors.grey,
              ),
            ),
            SizedBox(height: context.h(3)),
            ElevatedButton(
              onPressed: retryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(6),
                  vertical: context.h(2),
                ),
              ),
              child: Text(
                LocaleKeys.retry.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.sp(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = [
      LocaleKeys.symptomCheckerSpecialty.tr(),
      LocaleKeys.symptomCheckerSymptoms.tr(),
      LocaleKeys.symptomCheckerAnalysis.tr(),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(2), vertical: context.h(1.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index == _currentStep.index;
          final isCompleted = index < _currentStep.index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(0.5)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(2),
                  vertical: context.h(1),
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : isCompleted
                          ? AppColors.success
                          : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? Border.all(color: AppColors.primary, width: 1)
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    step,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          isActive || isCompleted ? Colors.white : Colors.grey,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: context.sp(11),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpecialtyPage() {
    // Cache categories to avoid repeated computation
    final categories =
        _data.categoriesData?[SymptomCheckerConstants.keyMapping] ??
            SymptomCheckerConstants.defaultMapping;

    return _buildPageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.symptomCheckerClinicalSpecialty.tr(),
              style: TextStyle(
                fontSize: context.sp(24),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.h(1)),
            Text(
              LocaleKeys.symptomCheckerSelectSpecialty.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                color: Colors.grey,
              ),
            ),
            SizedBox(height: context.h(3)),
            // Use LayoutBuilder for better performance
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heart Category
                    Expanded(
                      child: _buildSpecialtyCardNew(
                        icon: '❤️',
                        title: LocaleKeys.symptomCheckerHeartVascular.tr(),
                        subtitle: LocaleKeys.symptomCheckerCardiacSystem.tr(),
                        isSelected: _data.category ==
                            SymptomCheckerConstants.categoryHeart,
                        onPressed: () => _selectCategory(
                            SymptomCheckerConstants.categoryHeart, categories),
                      ),
                    ),
                    SizedBox(width: context.w(4)),
                    // General Category
                    Expanded(
                      child: _buildSpecialtyCardNew(
                        icon: '🏥',
                        title: LocaleKeys.symptomCheckerGeneralMedicine.tr(),
                        subtitle: LocaleKeys.symptomCheckerComprehensive.tr(),
                        isSelected: _data.category ==
                            SymptomCheckerConstants.categoryGeneral,
                        onPressed: () => _selectCategory(
                            SymptomCheckerConstants.categoryGeneral,
                            categories),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: context.h(2)),
            Container(
              padding: EdgeInsets.all(context.w(3)),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: context.w(2)),
                  Expanded(
                    child: Text(
                      LocaleKeys.symptomCheckerTip.tr(),
                      style: TextStyle(
                        fontSize: context.sp(14),
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.h(3)),
            _buildNavigationButtons(
              showPrevious: true,
              onNext: _nextStep,
            ),
          ],
        ),
      ),
    );
  }

  void _selectCategory(String category, Map<String, dynamic> categories) {
    setState(() {
      _data.category = category;
      final categoryList = categories[category];
      if (categoryList != null && categoryList.isNotEmpty) {
        _data.subCategory = categoryList.first;
      } else {
        _data.subCategory = category == SymptomCheckerConstants.categoryHeart
            ? SymptomCheckerConstants.defaultHeartSubCategory
            : SymptomCheckerConstants.defaultGeneralSubCategory;
      }
    });
    _nextStep();
  }

  Widget _buildSpecialtyCardNew({
    required String icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: SymptomCheckerConstants.mediumAnimationDuration,
        padding:
            EdgeInsets.all(context.w(SymptomCheckerConstants.paddingMedium)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ]
                : [
                    Colors.white,
                    Colors.grey.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius:
              BorderRadius.circular(SymptomCheckerConstants.borderRadiusXLarge),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  icon,
                  style: TextStyle(
                      fontSize:
                          context.sp(SymptomCheckerConstants.iconSizeXLarge)),
                ),
                SizedBox(
                    width: context.w(SymptomCheckerConstants.paddingSmall)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize:
                              context.sp(SymptomCheckerConstants.fontSizeLarge),
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(
                          height:
                              context.h(SymptomCheckerConstants.spacingSmall)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: context
                              .sp(SymptomCheckerConstants.fontSizeMedium),
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(SymptomCheckerConstants.spacingMedium)),
            Container(
              width: double.infinity,
              height: context.h(SymptomCheckerConstants.spacingSmall),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[300],
                borderRadius: BorderRadius.circular(
                    SymptomCheckerConstants.borderRadiusSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsPage() {
    if (_data.categoriesData == null) {
      return _buildLoadingState();
    }

    // Get symptoms data with translations from API
    final symptomsData =
        _data.categoriesData?[SymptomCheckerConstants.keySymptomsData]
            as Map<String, dynamic>?;

    // Get the mapping to filter by parent category
    final mapping = _data.categoriesData?[SymptomCheckerConstants.keyMapping]
        as Map<String, dynamic>?;

    if (symptomsData == null || symptomsData.isEmpty) {
      return _buildErrorState(
        message: LocaleKeys.symptomCheckerErrorLoading.tr(),
        onRetry: _loadInitialData,
      );
    }

    // Get allowed sub-categories based on parent category selection
    final allowedSubCategories = mapping != null
        ? (mapping[_data.category] as List<dynamic>?)?.cast<String>() ?? []
        : [];

    // Debug: Print what we received from API
    debugPrint('API Mapping: $mapping');
    debugPrint('Selected Category: ${_data.category}');
    debugPrint('Allowed SubCategories: $allowedSubCategories');

    // Get all category keys that have symptoms AND belong to selected parent category
    var availableCategories = symptomsData.entries
        .where((e) =>
            (e.value as List).isNotEmpty &&
            allowedSubCategories.contains(e.key))
        .map((e) => e.key)
        .toList();

    // Fallback: If no categories match the filter, show all categories with symptoms
    if (availableCategories.isEmpty) {
      debugPrint('No categories matched filter, using fallback');
      availableCategories = symptomsData.entries
          .where((e) => (e.value as List).isNotEmpty)
          .map((e) => e.key)
          .toList();
    }

    if (availableCategories.isEmpty) {
      return _buildPageContainer(
        child: Center(
          child: Text(
            LocaleKeys.symptomCheckerNoSymptomsMessage.tr(),
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // Ensure subCategory is valid
    if (!availableCategories.contains(_data.subCategory)) {
      _data.subCategory = availableCategories.first;
    }

    // Get symptoms for current category
    final currentSymptoms = symptomsData[_data.subCategory] as List<dynamic>;

    // Debug logging
    debugPrint('=== SYMPTOM DEBUG ===');
    debugPrint('Category: ${_data.category}');
    debugPrint('SubCategory: ${_data.subCategory}');
    debugPrint('Available Categories: $availableCategories');
    debugPrint('SymptomsData keys: ${symptomsData.keys.toList()}');
    debugPrint('Current symptoms count: ${currentSymptoms.length}');
    debugPrint('Current symptoms: $currentSymptoms');
    debugPrint('=====================');

    return _buildPageContainer(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.symptomCheckerSymptomAssessment.tr(),
                  style: TextStyle(
                    fontSize: context.sp(24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.h(0.5)),
                Text(
                  LocaleKeys.symptomCheckerSelectSymptoms.tr(),
                  style: TextStyle(
                    fontSize: context.sp(16),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingMedium)),

                // Category Cards Row
                Text(
                  LocaleKeys.symptomCheckerSelectSpecialty.tr(),
                  style: TextStyle(
                    fontSize:
                        context.sp(SymptomCheckerConstants.fontSizeXLarge),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingMedium)),
                SizedBox(
                  height: context.h(SymptomCheckerConstants.categoryCardHeight),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                        right:
                            context.w(SymptomCheckerConstants.paddingXLarge)),
                    itemCount: availableCategories.length,
                    itemBuilder: (context, index) {
                      final category = availableCategories[index];
                      final isSelected = category == _data.subCategory;
                      final categorySymptoms = symptomsData[category] as List;
                      final categoryDisplayName =
                          _getCategoryDisplayName(category);

                      return Padding(
                        padding: EdgeInsets.only(
                            left: index == 0
                                ? context
                                    .w(SymptomCheckerConstants.paddingSmall)
                                : 0,
                            right: context
                                .w(SymptomCheckerConstants.paddingSmall)),
                        child: _buildCategoryCard(
                          category: category,
                          displayName: categoryDisplayName,
                          icon: _getCategoryIcon(category),
                          count: categorySymptoms.length,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _data.subCategory = category;
                              _data.selectedSymptoms.clear();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingLarge)),

                // Symptoms Section Title
                Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color: AppColors.primary,
                      size: context.sp(SymptomCheckerConstants.iconSizeLarge),
                    ),
                    SizedBox(
                        width: context.w(SymptomCheckerConstants.paddingSmall)),
                    Expanded(
                      child: Text(
                        '${_getCategoryDisplayName(_data.subCategory)} ${LocaleKeys.symptomCheckerSymptoms.tr()}:',
                        style: TextStyle(
                          fontSize: context
                              .sp(SymptomCheckerConstants.fontSizeXXLarge),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingMedium)),
              ],
            ),
          ),

          // Symptoms Grid
          currentSymptoms.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.all(
                        context.w(SymptomCheckerConstants.paddingXLarge)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: context
                              .w(SymptomCheckerConstants.iconSizeXLarge * 5),
                          height: context
                              .w(SymptomCheckerConstants.iconSizeXLarge * 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medical_information_outlined,
                            size: context
                                .sp(SymptomCheckerConstants.iconSizeXLarge * 2),
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                            height: context
                                .h(SymptomCheckerConstants.spacingXLarge)),
                        Text(
                          LocaleKeys.symptomCheckerNoSymptomsMessage.tr(),
                          style: TextStyle(
                            fontSize: context
                                .sp(SymptomCheckerConstants.fontSizeLarge),
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                            height: context
                                .h(SymptomCheckerConstants.spacingMedium)),
                        Text(
                          LocaleKeys.symptomCheckerTip.tr(),
                          style: TextStyle(
                            fontSize: context
                                .sp(SymptomCheckerConstants.fontSizeMedium),
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: EdgeInsets.only(
                      bottom: context.h(SymptomCheckerConstants.spacingMedium)),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final symptomData =
                            currentSymptoms[index] as Map<String, dynamic>;
                        final symptomId = symptomData['id']?.toString() ?? '';
                        final displayName =
                            symptomData['name']?.toString() ?? symptomId;
                        final description =
                            symptomData['description']?.toString();
                        final severity =
                            symptomData['severity']?.toString() ?? 'moderate';
                        final isSelected =
                            _data.selectedSymptoms.contains(symptomId);

                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: context
                                  .h(SymptomCheckerConstants.spacingSmall)),
                          child: _buildSymptomCard(
                            symptomId: symptomId,
                            name: displayName,
                            description: description,
                            severity: severity,
                            icon: _getSymptomIcon(symptomId, displayName),
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (_data.selectedSymptoms
                                    .contains(symptomId)) {
                                  _data.removeSymptom(symptomId);
                                } else {
                                  _data.addSymptom(symptomId);
                                }
                              });
                            },
                          ),
                        );
                      },
                      childCount: currentSymptoms.length,
                    ),
                  ),
                ),

          // Bottom Section
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingMedium)),

                // Selected Count with better design
                if (_data.selectedSymptoms.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                        context.w(SymptomCheckerConstants.paddingLarge)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.success.withValues(alpha: 0.15),
                          AppColors.success.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          SymptomCheckerConstants.borderRadiusLarge),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: context
                              .sp(SymptomCheckerConstants.iconSizeMedium),
                        ),
                        SizedBox(
                            width: context
                                .w(SymptomCheckerConstants.paddingSmall)),
                        Flexible(
                          child: Text(
                            LocaleKeys.symptomCheckerSelectedCount.tr(args: [
                              _data.selectedSymptoms.length.toString()
                            ]),
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: context
                                  .sp(SymptomCheckerConstants.fontSizeLarge),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingLarge)),

                // Navigation
                _buildNavigationButtons(
                  showPrevious: true,
                  onNext: _data.selectedSymptoms.isNotEmpty
                      ? _analyzeSymptoms
                      : () => _showNoSymptomsWarning(),
                  nextText: LocaleKeys.symptomCheckerAnalyzeSymptoms.tr(),
                ),
                SizedBox(
                    height: context.h(SymptomCheckerConstants.spacingLarge)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get icon for symptom based on symptom ID or name
  String _getSymptomIcon(String symptomId, String symptomName) {
    // Try to find icon by symptom ID first (lowercase, replace spaces with underscores)
    final idKey = symptomId.toLowerCase().replaceAll(' ', '_');
    if (SymptomCheckerConstants.symptomIcons.containsKey(idKey)) {
      return SymptomCheckerConstants.symptomIcons[idKey]!;
    }

    // Try to find icon by symptom name
    final nameKey = symptomName.toLowerCase().replaceAll(' ', '_');
    if (SymptomCheckerConstants.symptomIcons.containsKey(nameKey)) {
      return SymptomCheckerConstants.symptomIcons[nameKey]!;
    }

    // Return default icon
    return SymptomCheckerConstants.symptomIcons['default']!;
  }

  // Get icon for category from constants
  String _getCategoryIcon(String category) {
    return SymptomCheckerConstants.categoryIcons[category] ?? '🏥';
  }

  // Get display name for category - uses translations primarily, falls back to constants
  String _getCategoryDisplayName(String category) {
    final translationKeys = {
      'Chest': LocaleKeys.symptomCheckerHeartVascular,
      'Cardiovascular': LocaleKeys.symptomCheckerCardiacSystem,
      'Respiratory': LocaleKeys.symptomCheckerCategoryRespiratory,
      'Neurological': LocaleKeys.symptomCheckerCategoryNeurological,
      'Gastrointestinal': LocaleKeys.symptomCheckerCategoryGastrointestinal,
      'Musculoskeletal': LocaleKeys.symptomCheckerCategoryMusculoskeletal,
      'General': LocaleKeys.symptomCheckerGeneralMedicine,
      'Other': LocaleKeys.symptomCheckerCategoryOther,
    };

    // Try to get translation first
    final key = translationKeys[category];
    if (key != null) {
      final translated = key.tr();
      // If translation returns the key name itself (not found), fall back
      if (!translated.contains('.')) return translated;
    }

    // Fall back to constants or category name
    return SymptomCheckerConstants.categoryDisplayNames[category] ?? category;
  }

  String _formatDate(DateTime date) {
    final now = date;
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getSeverityEmoji(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return '🚨';
      case 'high':
        return '⚠️';
      case 'moderate':
      case 'low':
        return '✅';
      default:
        return '✅';
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return AppColors.riskCritical;
      case 'high':
        return AppColors.riskHigh;
      case 'moderate':
      case 'low':
        return AppColors.success;
      default:
        return AppColors.success;
    }
  }

  // Get step title with translation
  String _getStepTitle(SymptomCheckerStep step) {
    switch (step) {
      case SymptomCheckerStep.specialty:
        return LocaleKeys.symptomCheckerSpecialty.tr();
      case SymptomCheckerStep.symptoms:
        return LocaleKeys.symptomCheckerSymptoms.tr();
      case SymptomCheckerStep.results:
        return LocaleKeys.symptomCheckerAnalysis.tr();
    }
  }

  Widget _buildCategoryCard({
    required String category,
    required String displayName,
    required String icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: SymptomCheckerConstants.mediumAnimationDuration,
        width: context.w(SymptomCheckerConstants.categoryCardWidth),
        padding:
            EdgeInsets.all(context.w(SymptomCheckerConstants.paddingSmall)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ]
                : [
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1e293b)
                        : Colors.white,
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0f172a)
                        : Colors.grey.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius:
              BorderRadius.circular(SymptomCheckerConstants.borderRadiusLarge),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.w(SymptomCheckerConstants.categoryCardIconSize),
              height: context.w(SymptomCheckerConstants.categoryCardIconSize),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                      fontSize:
                          context.sp(SymptomCheckerConstants.iconSizeEmoji)),
                ),
              ),
            ),
            SizedBox(height: context.h(SymptomCheckerConstants.spacingSmall)),
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: context.sp(SymptomCheckerConstants.fontSizeMedium),
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
                height: context.h(SymptomCheckerConstants.spacingSmall / 2)),
            Text(
              '$count ${LocaleKeys.symptomCheckerSymptoms.tr().toLowerCase()}',
              style: TextStyle(
                fontSize: context.sp(SymptomCheckerConstants.fontSizeSmall),
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomCard({
    required String symptomId,
    required String name,
    required String? description,
    required String severity,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final severityColors = {
      SymptomCheckerConstants.severityCritical: AppColors.riskCritical,
      SymptomCheckerConstants.severityHigh: AppColors.riskHigh,
      SymptomCheckerConstants.severityModerate: AppColors.riskModerate,
      SymptomCheckerConstants.severityLow: AppColors.success,
    };

    final severityIcons = {
      SymptomCheckerConstants.severityCritical: Icons.priority_high,
      SymptomCheckerConstants.severityHigh: Icons.warning_amber,
      SymptomCheckerConstants.severityModerate: Icons.info_outline,
      SymptomCheckerConstants.severityLow: Icons.check_circle_outline,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: SymptomCheckerConstants.animationDuration,
        padding: EdgeInsets.symmetric(
          horizontal: context.w(SymptomCheckerConstants.symptomCardPadding),
          vertical: context.h(SymptomCheckerConstants.paddingSmall),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ]
                : [
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1e293b)
                        : Colors.white,
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0f172a)
                        : Colors.grey.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius:
              BorderRadius.circular(SymptomCheckerConstants.borderRadiusLarge),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (severityColors[severity] ?? Colors.grey)
                    .withValues(alpha: 0.3),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Selection checkbox with animation
            AnimatedContainer(
              duration: SymptomCheckerConstants.shortAnimationDuration,
              width: context.w(SymptomCheckerConstants.iconSizeSmall),
              height: context.w(SymptomCheckerConstants.iconSizeSmall),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (severityColors[severity] ?? Colors.grey)
                        .withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (severityColors[severity] ?? Colors.grey)
                          .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  isSelected
                      ? Icons.check
                      : (severityIcons[severity] ?? Icons.healing),
                  color: isSelected
                      ? Colors.white
                      : (severityColors[severity] ?? Colors.grey),
                  size: context.sp(SymptomCheckerConstants.iconSizeSmall),
                ),
              ),
            ),
            SizedBox(width: context.w(SymptomCheckerConstants.paddingSmall)),
            // Symptom icon
            Container(
              width: context.w(SymptomCheckerConstants.iconSizeMedium),
              height: context.w(SymptomCheckerConstants.iconSizeMedium),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: context.sp(SymptomCheckerConstants.iconSizeSmall),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.w(SymptomCheckerConstants.paddingSmall)),
            // Symptom info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize:
                          context.sp(SymptomCheckerConstants.fontSizeMedium),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primary : null,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                          top: context
                              .h(SymptomCheckerConstants.spacingSmall / 2)),
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize:
                              context.sp(SymptomCheckerConstants.fontSizeSmall),
                          color: Colors.grey[600],
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPage() {
    if (_data.analysisResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _data.analysisResult!;
    final disease = result['disease'] ?? 'Unknown';
    final confidence = result['confidence'] ?? 0.0;
    final severity = result['severity'] ?? 'moderate';
    final advice = result['advice'] ?? LocaleKeys.symptomCheckerTip.tr();

    final severityColors = {
      'critical': AppColors.riskCritical,
      'high': AppColors.riskHigh,
      'moderate': AppColors.riskModerate,
      'low': AppColors.riskLow,
    };

    final severityEmojis = SymptomCheckerConstants.severityEmojis;

    return _buildPageContainer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(6)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    severityEmojis[severity] ?? 'ℹ️',
                    style: TextStyle(fontSize: context.sp(64)),
                  ),
                  SizedBox(height: context.h(2)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(4),
                      vertical: context.h(1.5),
                    ),
                    decoration: BoxDecoration(
                      color: severityColors[severity]?.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            severityColors[severity] ?? AppColors.riskModerate,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      LocaleKeys.symptomCheckerRiskLevel
                          .tr(args: [severity.toUpperCase()]),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: severityColors[severity],
                        fontSize: context.sp(14),
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(1)),
                  Text(
                    LocaleKeys.symptomCheckerAiAnalysisComplete.tr(),
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: context.sp(12),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: context.h(2)),
                  Text(
                    disease,
                    style: TextStyle(
                      fontSize: context.sp(32),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.h(1)),
                  Text(
                    LocaleKeys.symptomCheckerConfidence
                        .tr(args: ['${(confidence as num).toDouble() * 100}']),
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.h(3)),
            _buildAdviceCard(advice),
            SizedBox(height: context.h(3)),
            _buildResultSummary(),
            SizedBox(height: context.h(3)),
            _buildNavigationButtons(
              showPrevious: false,
              onNext: _resetAssessment,
              nextText: LocaleKeys.symptomCheckerNewAssessment.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContainer({required Widget child}) {
    return Padding(
      padding: EdgeInsets.all(context.w(SymptomCheckerConstants.paddingMedium)),
      child: child,
    );
  }

  void _resetAssessment() {
    setState(() {
      _data.clearSelection();
      _data.analysisResult = null;
      _currentStep = SymptomCheckerStep.specialty;
    });
    _pageController.animateToPage(
      0,
      duration: SymptomCheckerConstants.pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  Widget _buildAdviceCard(String advice) {
    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '💚',
                style: TextStyle(fontSize: context.sp(24)),
              ),
              SizedBox(width: context.w(2)),
              Expanded(
                child: Text(
                  LocaleKeys.symptomCheckerExpertGuidance.tr(),
                  style: TextStyle(
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(2)),
          Text(
            advice,
            style: TextStyle(
              fontSize: context.sp(16),
              height: 1.8,
            ),
          ),
          SizedBox(height: context.h(2)),
        ],
      ),
    );
  }

  Widget _buildResultSummary() {
    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0f172a),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.contactsTitle.tr(),
            style: TextStyle(
              fontSize: context.sp(20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.h(2)),
          _buildResultItem(
            label: LocaleKeys.symptomCheckerClinicalSpecialty.tr(),
            value:
                '${_getCategoryDisplayName(_data.category)} | ${_getCategoryDisplayName(_data.subCategory)}',
          ),
          _buildResultItem(
            label: LocaleKeys.symptomCheckerSelectedCount.tr(),
            value: '${_data.selectedSymptoms.length}',
          ),
          _buildResultItem(
            label: LocaleKeys.symptomCheckerAnalysis.tr(),
            value: _data.analysisResult?['disease'] ??
                LocaleKeys.symptomCheckerUnknownError.tr(),
          ),
          _buildResultItem(
            label: LocaleKeys.symptomCheckerRiskLevel.tr(),
            value:
                '${_data.analysisResult?['severity'] ?? 'moderate'} ${_getSeverityEmoji(_data.analysisResult?['severity'])}',
            valueColor: _getSeverityColor(_data.analysisResult?['severity']),
          ),
          _buildResultItem(
            label: LocaleKeys.symptomCheckerDate.tr(),
            value: _formatDate(DateTime.now()),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.h(0.8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: context.sp(14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.grey[300],
              fontSize: context.sp(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons({
    required bool showPrevious,
    VoidCallback? onNext,
    String? nextText,
  }) {
    return Row(
      children: [
        if (showPrevious) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                    vertical: context.h(SymptomCheckerConstants.paddingMedium)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      SymptomCheckerConstants.borderRadiusLarge),
                ),
                side: BorderSide(color: AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: AppColors.primary,
                    size: context.sp(SymptomCheckerConstants.iconSizeMedium),
                  ),
                  SizedBox(
                      width: context.w(SymptomCheckerConstants.spacingSmall)),
                  Flexible(
                    child: Text(
                      LocaleKeys.symptomCheckerBack.tr(),
                      style: TextStyle(
                        fontSize:
                            context.sp(SymptomCheckerConstants.fontSizeLarge),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: context.w(SymptomCheckerConstants.paddingMedium)),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                  vertical: context.h(SymptomCheckerConstants.paddingMedium)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    SymptomCheckerConstants.borderRadiusLarge),
              ),
            ),
            child: Text(
              nextText ?? LocaleKeys.symptomCheckerNewAssessment.tr(),
              style: TextStyle(
                fontSize: context.sp(SymptomCheckerConstants.fontSizeLarge),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  void _showNoSymptomsWarning() {
    ProfessionalErrorHandler.showWarningDialog(
      context: context,
      titleKey: LocaleKeys.symptomCheckerNoSymptomsSelected,
      messageKey: LocaleKeys.symptomCheckerNoSymptomsMessage,
      confirmText: LocaleKeys.symptomCheckerSelectSymptomsLabel.tr(),
      cancelText: LocaleKeys.back.tr(),
      onConfirm: () {
        Navigator.of(context).pop();
        // Focus on the symptoms list
      },
      onCancel: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _analyzeSymptoms() async {
    try {
      // Get current app locale
      final currentLocale = context.locale.languageCode;

      final repository = ref.read(aiRepositoryProvider);
      final result = await repository.analyzeSymptoms(
        category: _data.category,
        subCategory: _data.subCategory,
        symptomIds: _data.selectedSymptoms,
        language: currentLocale,
      );

      setState(() {
        _data.analysisResult = result;
      });

      _nextStep();
    } catch (e) {
      if (mounted) {
        // Handle specific connection errors
        if (e.toString().contains('ConnectionError') ||
            e.toString().contains('connection error') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('NetworkException')) {
          ProfessionalErrorHandler.showErrorDialog(
            context: context,
            titleKey: 'common.no_internet',
            messageKey: 'common.check_internet_connection',
            onRetry: _analyzeSymptoms,
            showRetry: true,
          );
        } else if (e.toString().contains('Invalid authentication') ||
            e.toString().contains('401') ||
            e.toString().contains('Unauthorized')) {
          ProfessionalErrorHandler.showErrorDialog(
            context: context,
            titleKey: 'auth.session_expired',
            messageKey: 'common.please_login_again',
            onRetry: () {
              // Navigate to login screen
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            showRetry: true,
          );
        } else {
          final errorInfo = ErrorHandlingService.detectErrorType(e);
          ProfessionalErrorHandler.showErrorDialog(
            context: context,
            titleKey: errorInfo.titleKey,
            messageKey: errorInfo.messageKey,
            subtitleKey: errorInfo.subtitleKey,
            onRetry: errorInfo.canRetry ? _analyzeSymptoms : null,
            showRetry: errorInfo.canRetry,
          );
        }
      }
    }
  }

  IconData _getStepIcon(SymptomCheckerStep step) {
    switch (step) {
      case SymptomCheckerStep.specialty:
        return Icons.medical_services;
      case SymptomCheckerStep.symptoms:
        return Icons.health_and_safety;
      case SymptomCheckerStep.results:
        return Icons.analytics_outlined;
    }
  }

  Widget _buildSidebarNavigation() {
    return Container(
      margin: EdgeInsets.all(context.w(2)),
      padding: EdgeInsets.all(context.w(3)),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1e293b)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            LocaleKeys.contactsTitle.tr(),
            style: TextStyle(
              fontSize: context.sp(18),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.primary,
            ),
          ),
          SizedBox(height: context.h(2)),
          ...SymptomCheckerStep.values.map((step) {
            final isActive = step == _currentStep;
            return Padding(
              padding: EdgeInsets.only(bottom: context.h(1)),
              child: InkWell(
                onTap: () => _goToStep(step),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(context.w(2)),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isActive ? Border.all(color: AppColors.primary) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStepIcon(step),
                        color: isActive ? AppColors.primary : Colors.grey,
                      ),
                      SizedBox(width: context.w(2)),
                      Expanded(
                        child: Text(
                          _getStepTitle(step),
                          style: TextStyle(
                            color: isActive ? AppColors.primary : Colors.grey,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
