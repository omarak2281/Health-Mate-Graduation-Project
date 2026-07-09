#include <Wire.h>
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include "MAX30105.h"

// Sensors & WiFi Config
const char* ssid = "HONOR 600";
const char* password = "87654321";
const char* serverUrl = "http://10.229.183.149:8000/api/v1/vitals/bp/submit";
const char* patientUserId = "00000000-0000-0000-0000-000000000001"; // Placeholder target patient ID
const char* deviceId = "esp8266-bp-sensor-001";
const char* deviceToken = "test-token"; // Secure device token used for authentication

MAX30105 ppg;

#define BUFF_SIZE 800
float ppgBuffer[BUFF_SIZE];
float ecgBuffer[BUFF_SIZE];
int sampleIdx = 0;

// SpO2 running statistics over the current 8s window (ratio-of-ratios method).
// We accumulate sum and sum-of-squares for Red and IR instead of buffering the
// Red channel, to stay within ESP8266 heap limits.
double redSum = 0, redSumSq = 0, irSum = 0, irSumSq = 0;

void resetSpo2Stats() {
  redSum = 0; redSumSq = 0; irSum = 0; irSumSq = 0;
}

// Compute SpO2 from the accumulated window statistics.
// R = (AC_red/DC_red) / (AC_ir/DC_ir), SpO2 = 110 - 25*R (standard MAX3010x
// empirical linear approximation). Returns -1 when the signal statistics are
// not usable (division hazard or physiologically implausible result).
int computeSpo2(int n) {
  if (n < 100) return -1; // need at least 1s of samples
  double redMean = redSum / n;
  double irMean = irSum / n;
  if (redMean < 1000.0 || irMean < 1000.0) return -1; // no finger / no light
  double redVar = (redSumSq / n) - (redMean * redMean);
  double irVar = (irSumSq / n) - (irMean * irMean);
  if (redVar <= 0.0 || irVar <= 0.0) return -1;
  double redAc = sqrt(redVar);
  double irAc = sqrt(irVar);
  double r = (redAc / redMean) / (irAc / irMean);
  int spo2 = (int)round(110.0 - 25.0 * r);
  // Physiologically plausible window only; anything else is a quality failure
  if (spo2 < 70 || spo2 > 100) return -1;
  return spo2;
}

int computeHeartRateFromPpg(int n) {
  if (n < 300) return -1; // need at least 3s of signal

  float minV = ppgBuffer[0];
  float maxV = ppgBuffer[0];
  for (int i = 1; i < n; i++) {
    if (ppgBuffer[i] < minV) minV = ppgBuffer[i];
    if (ppgBuffer[i] > maxV) maxV = ppgBuffer[i];
  }

  float amplitude = maxV - minV;
  if (amplitude < 1000.0) return -1;

  const int minPeakDistance = 33; // 100Hz / 180bpm
  const int maxPeaks = 20;
  int peaks[maxPeaks];
  int peakCount = 0;
  int lastPeak = -minPeakDistance;
  float threshold = minV + (amplitude * 0.55);

  for (int i = 1; i < n - 1 && peakCount < maxPeaks; i++) {
    bool isPeak = ppgBuffer[i] > threshold &&
                  ppgBuffer[i] >= ppgBuffer[i - 1] &&
                  ppgBuffer[i] > ppgBuffer[i + 1];
    if (isPeak && (i - lastPeak) >= minPeakDistance) {
      peaks[peakCount++] = i;
      lastPeak = i;
    }
  }

  if (peakCount < 2) return -1;

  long intervalSum = 0;
  for (int i = 1; i < peakCount; i++) {
    intervalSum += peaks[i] - peaks[i - 1];
  }

  float avgIntervalSamples = (float)intervalSum / (float)(peakCount - 1);
  if (avgIntervalSamples <= 0) return -1;

  int bpm = (int)round(6000.0 / avgIntervalSamples); // 60s * 100Hz
  if (bpm < 40 || bpm > 180) return -1;
  return bpm;
}

#define ECG_PIN  A0
#define SDN_PIN  D5
#define LO_PLUS  D6
#define LO_MINUS D7

unsigned long lastSampleTime = 0;
bool wifiConnected = false;
int consecutiveErrors = 0;
const int maxConsecutiveErrors = 50; // 500ms at 100Hz

// Helper definition moved before checkGating to prevent compilation/link errors
bool digitalReadLO_MINUS() {
  return digitalRead(LO_MINUS) == HIGH;
}

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    wifiConnected = true;
  } else {
    Serial.println("\nWiFi Connection Failed (Will retry later)");
    wifiConnected = false;
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(SDN_PIN, OUTPUT);
  pinMode(LO_PLUS,  INPUT);
  pinMode(LO_MINUS, INPUT);
  digitalWrite(SDN_PIN, HIGH); // Enable AD8232 ECG sensor chip

  // MAX30102 Setup (sampleAverage=1 to get raw 100Hz signals)
  if (!ppg.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR:MAX30102_NOT_FOUND");
    while (1) { delay(1000); }
  }
  // sampleAverage: 1, ledMode: 2 (IR + Red), sampleRate: 100, pulseWidth: 411, adcRange: 4096
  ppg.setup(60, 1, 2, 100, 411, 4096);

  connectWiFi();
  Serial.println("READY - Place finger on PPG and attach ECG leads to start...");
  lastSampleTime = millis();
}

bool checkGating() {
  // 1. Leads Status: AD8232 leads must be connected
  bool leadsOk = (digitalRead(LO_PLUS) == LOW && digitalReadLO_MINUS() == LOW);
  if (!leadsOk) {
    Serial.println("GATING_ERROR:ECG_LEADS_DETECTED_DISCONNECTED");
    return false;
  }

  // 2. Finger Detection: PPG IR must detect a finger (> 50,000 counts)
  ppg.check();
  long ir = ppg.getIR();
  if (ir < 50000) {
    Serial.println("GATING_ERROR:PPG_NO_FINGER_DETECTED");
    return false;
  }

  return true;
}

void submitData() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Disconnected, reconnecting...");
    WiFi.begin(ssid, password);
    delay(1000);
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Reconnection failed, skipping packet.");
      return;
    }
  }

  WiFiClient client;
  HTTPClient http;
  
  Serial.println("[COLLECTING] Assembling JSON packet...");
  // Assemble JSON string manually to optimize heap memory usage on ESP8266/ESP32.
  // We send only integers or compact float representation to reduce JSON payload size.
  String json = "{\"device_id\":\"" + String(deviceId) + "\",\"ppg_signal\":[";
  for (int i = 0; i < BUFF_SIZE; i++) {
    json += String((int)ppgBuffer[i]);
    if (i < BUFF_SIZE - 1) json += ",";
  }
  json += "],\"ecg_signal\":[";
  for (int i = 0; i < BUFF_SIZE; i++) {
    json += String((int)ecgBuffer[i]);
    if (i < BUFF_SIZE - 1) json += ",";
  }
  json += "]";

  // Attach SpO2 only when the window statistics produced a plausible value;
  // the backend treats a missing spo2 as "not measured", never as 0.
  int spo2 = computeSpo2(BUFF_SIZE);
  if (spo2 > 0) {
    json += ",\"spo2\":" + String(spo2);
    Serial.print("[SPO2] Window SpO2 = ");
    Serial.println(spo2);
  } else {
    Serial.println("[SPO2] Signal not usable for SpO2 this window, omitting.");
  }

  int bpm = computeHeartRateFromPpg(BUFF_SIZE);
  if (bpm > 0) {
    json += ",\"heart_rate\":" + String(bpm);
    Serial.print("[BPM] Window heart rate = ");
    Serial.println(bpm);
  } else {
    Serial.println("[BPM] Signal not usable for BPM this window, omitting.");
  }
  json += "}";

  Serial.println("[COLLECTING] Sending data to backend...");
  
  // Exponential Backoff Retry Policy
  int retryDelaySec = 2;
  int maxRetries = 4;
  bool success = false;
  
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    http.begin(client, serverUrl);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-ID", deviceId);
    http.addHeader("X-Device-Token", deviceToken);
    
    int httpResponseCode = http.POST(json);
    if (httpResponseCode == 201 || httpResponseCode == 200) {
      Serial.print("[UPLOAD_OK] Success! HTTP Response: ");
      Serial.println(httpResponseCode);
      success = true;
      http.end();
      break;
    } else {
      Serial.print("[UPLOAD_FAIL] Attempt ");
      Serial.print(attempt);
      Serial.print(" failed. HTTP Code: ");
      Serial.println(httpResponseCode);
      if (httpResponseCode == 401 || httpResponseCode == 403 || httpResponseCode == 422) {
        Serial.println("[BACKEND_REJECTED] Request structural error or unauthorized. Aborting.");
        http.end();
        break;
      }
      if (attempt < maxRetries) {
        Serial.print("[WiFi] Retrying in ");
        Serial.print(retryDelaySec);
        Serial.println(" seconds...");
        delay(retryDelaySec * 1000);
        retryDelaySec *= 2; // Double delay
      } else {
        Serial.println("[UPLOAD_FAIL] Max retries exceeded. Dropping measurement.");
      }
    }
    http.end();
  }
}

unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 10000; // 10 seconds

// Last finger/leads state reported to the backend. When either changes we
// send a heartbeat immediately (instead of waiting up to 10s), so the app
// can warn the patient about a finger/lead loss while it is still happening.
bool lastSentLeadsOk = true;
bool lastSentFingerOk = true;
unsigned long lastStateChangeCheck = 0;

void sendHeartbeat(bool leadsOk, bool fingerOk) {
  if (WiFi.status() != WL_CONNECTED) return;
  
  WiFiClient client;
  HTTPClient http;
  
  String heartbeatUrl = String(serverUrl);
  heartbeatUrl.replace("/submit", "/heartbeat");
  
  http.begin(client, heartbeatUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-ID", deviceId);
  http.addHeader("X-Device-Token", deviceToken);
  
  String payload = "{\"leads_connected\":" + String(leadsOk ? "true" : "false") +
                   ",\"finger_detected\":" + String(fingerOk ? "true" : "false") + "}";
                   
  int httpResponseCode = http.POST(payload);
  http.end();
}

void loop() {
  unsigned long now = millis();

  // Send periodic heartbeat check, plus an immediate heartbeat whenever the
  // finger/leads state changes (checked at most once per second) so the app
  // learns about a mid-measurement finger or lead loss in ~1s, not up to 10s.
  if (now - lastStateChangeCheck >= 1000) {
    lastStateChangeCheck = now;
    bool leadsOk = (digitalRead(LO_PLUS) == LOW && digitalRead(LO_MINUS) == LOW);
    ppg.check();
    long ir = ppg.getIR();
    bool fingerOk = (ir > 50000);

    bool stateChanged = (leadsOk != lastSentLeadsOk) || (fingerOk != lastSentFingerOk);
    if (stateChanged || (now - lastHeartbeatTime >= heartbeatInterval)) {
      lastHeartbeatTime = now;
      lastSentLeadsOk = leadsOk;
      lastSentFingerOk = fingerOk;
      sendHeartbeat(leadsOk, fingerOk);
    }
  }

  // Enforce precise 100 Hz sampling (every 10ms)
  if (now - lastSampleTime >= 10) {
    lastSampleTime = now;

    // Check leads and sensor gating
    if (!checkGating()) {
      consecutiveErrors++;
      if (consecutiveErrors >= maxConsecutiveErrors) {
        if (sampleIdx > 0) {
          Serial.println("Finger removed or leads detached, resetting window buffer after 500ms.");
          sampleIdx = 0;
          resetSpo2Stats();
        }
      }
      delay(10);
      return;
    } else {
      consecutiveErrors = 0; // Reset error count on successful gating check
    }

    // Read PPG sample (IR for the BP model buffer, Red+IR for SpO2 stats)
    long ir = ppg.getIR();
    long red = ppg.getRed();
    ppg.nextSample(); // Advance sample queue

    redSum += (double)red;
    redSumSq += (double)red * (double)red;
    irSum += (double)ir;
    irSumSq += (double)ir * (double)ir;

    // Read analog ECG value
    int ecgVal = analogRead(ECG_PIN);

    // Save normalized/raw values to signal buffers
    ppgBuffer[sampleIdx] = (float)ir;
    ecgBuffer[sampleIdx] = (float)ecgVal;
    
    sampleIdx++;
    
    if (sampleIdx % 100 == 0) {
      Serial.print("Buffered ");
      Serial.print(sampleIdx);
      Serial.println("/800 samples...");
    }

    if (sampleIdx >= BUFF_SIZE) {
      Serial.println("Window full (8.0s), transferring to backend...");
      submitData();
      sampleIdx = 0; // Reset for next reading window
      resetSpo2Stats();
    }
  }
}
