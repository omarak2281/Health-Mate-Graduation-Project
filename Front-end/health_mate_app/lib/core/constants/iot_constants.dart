/// IoT Constants
/// All configuration values for ESP32 Smart Medication Box communication.
/// Update [esp32BaseUrl] to match the local IP of the ESP32 on the Wi-Fi network.

class IoTConstants {
  IoTConstants._();

  // ─── ESP32 Network Configuration ──────────────────────────────────────────
  /// Static IP of the ESP32 on the local network.
  /// Change this when deploying to a different environment.
  static const String esp32BaseUrl = 'http://10.229.183.78';

  // ─── Endpoints ─────────────────────────────────────────────────────────────
  /// POST endpoint to control (activate/deactivate) drawers.
  /// Body: {"drawers": [1, 3]}  — empty array turns everything off.
  static const String activateEndpoint = '/activate';

  // ─── Smart Box Hardware ────────────────────────────────────────────────────
  /// Total number of physical drawers in the Smart Medication Box.
  static const int totalDrawers = 6;

  // ─── Snooze ────────────────────────────────────────────────────────────────
  /// Snooze duration in minutes before the alarm re-triggers.
  static const int snoozeDurationMinutes = 5;

  // ─── Connection Timeouts ────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 5);
}
