import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/iot_constants.dart';

/// IoT Service
/// Handles direct HTTP communication with the ESP32 Smart Medication Box.
/// All ESP32-specific logic is isolated here to comply with Clean Architecture.
class IoTService {
  final http.Client _httpClient;

  IoTService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Sends a POST request to the ESP32 to activate or deactivate drawers.
  ///
  /// [drawerNumbers] — list of drawers to light up.
  ///   Pass an empty list `[]` to turn off all LEDs and the buzzer.
  ///
  /// Example payloads:
  ///   Activate drawer 3  → {"drawers": [3]}
  ///   Turn off hardware  → {"drawers": []}
  Future<void> controlDrawers(List<int> drawerNumbers) async {
    final url = Uri.parse(
      '${IoTConstants.esp32BaseUrl}${IoTConstants.activateEndpoint}',
    );
    final body = jsonEncode({'drawers': drawerNumbers});

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(IoTConstants.connectTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[IoTService] ESP32 returned ${response.statusCode}: ${response.body}',
        );
      } else {
        debugPrint('[IoTService] controlDrawers($drawerNumbers) → OK');
      }
    } catch (e) {
      // Network errors silently fail so they don't block the UI flow.
      debugPrint('[IoTService] controlDrawers error: $e');
    }
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────
final iotServiceProvider = Provider<IoTService>((ref) => IoTService());
