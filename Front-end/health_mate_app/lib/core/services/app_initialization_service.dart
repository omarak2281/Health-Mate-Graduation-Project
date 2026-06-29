import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/ai/services/model_data_service.dart';

/// App initialization service to handle startup tasks
class AppInitializationService {
  final ModelDataService _modelService;

  AppInitializationService(this._modelService);

  /// Initialize app services on startup
  Future<void> initializeApp() async {
    try {
      // Load model info in background
      await _modelService.loadModelInfo();
    } catch (e) {
      debugPrint('Failed to initialize app: $e');
      // Continue app initialization even if model loading fails
    }
  }
}

// Provider for app initialization service
final appInitializationServiceProvider =
    Provider<AppInitializationService>((ref) {
  final modelService = ref.watch(modelDataServiceProvider);
  return AppInitializationService(modelService);
});

// Async provider to handle app initialization
final appInitializationProvider = FutureProvider<void>((ref) async {
  final service = ref.read(appInitializationServiceProvider);
  await service.initializeApp();
});
