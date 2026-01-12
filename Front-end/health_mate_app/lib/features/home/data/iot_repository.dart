import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// IoT Repository
/// Handles interactions with sensors and smart medicine box

class IoTRepository {
  final DioClient _dioClient;

  IoTRepository(this._dioClient);

  // Get sensors status
  Future<List<dynamic>> getSensorsStatus() async {
    final response = await _dioClient.dio.get(ApiConstants.sensorsStatus);
    return response.data;
  }

  // Get medicine box drawers
  Future<List<dynamic>> getDrawers() async {
    final response = await _dioClient.dio.get(ApiConstants.medicineBoxDrawers);
    return response.data;
  }

  // Activate drawer
  Future<void> activateDrawer(int drawerNumber) async {
    await _dioClient.dio.post(ApiConstants.drawerActivate(drawerNumber));
  }

  // Deactivate drawer
  Future<void> deactivateDrawer(int drawerNumber) async {
    await _dioClient.dio.post(ApiConstants.drawerDeactivate(drawerNumber));
  }
}

final iotRepositoryProvider = Provider<IoTRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return IoTRepository(dioClient);
});
