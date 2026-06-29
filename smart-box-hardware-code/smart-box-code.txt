#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

// 1. اكتب هنا إعدادات شبكة الواي فاي الخاصة بك (نفس الشبكة اللي عليها الموبايل واللاب)
const char* ssid = "HONOR 600";
const char* password = "87654321";

WebServer server(80); // السيرفر هيشتغل على بورت 80 المحلي

// 2. تعريف بنات الهاردوير المستقرة (الـ 6 أدراج والبازر)
const int dataPin = 23;   // DS على 74HC595
const int clockPin = 18;  // SH_CP على 74HC595
const int latchPin = 5;   // ST_CP على 74HC595
const int buzzerPin = 4;  // بن البازر متصل بـ D4

void setup() {
  Serial.begin(115200);
  
  pinMode(dataPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  pinMode(latchPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  // قفل كل الليدات والبازر في البداية لضمان الاستقرار
  updateShiftRegister(0b00000000);
  digitalWrite(buzzerPin, LOW);

  // بدء الاتصال بالواي فاي
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  // طباعة الـ IP اللي هتاخده تحطه في كود الـ Flutter
  Serial.println("");
  Serial.println("WiFi connected.");
  Serial.print("ESP32 IP Address: ");
  Serial.println(WiFi.localIP()); 

  // تعريف الـ Endpoint اللي الأبليكيشن هيبعت عليها الـ JSON
  server.on("/activate", HTTP_POST, handleActivateDrawer);
  
  server.begin();
  Serial.println("HTTP Server Started!");
}

void loop() {
  server.handleClient(); // الاستمرار في الاستماع لطلبات الأبليكيشن (Flutter)
}

// دالة التعامل مع الطلب القادم من الأبليكيشن (تنور الليد وتشغل البازر أو تطفي كله)
void handleActivateDrawer() {
  if (server.hasArg("plain") == false) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Body not found\"}");
    return;
  }

  String jsonString = server.arg("plain");
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, jsonString);

  if (error) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
    return;
  }

  // التحقق من وجود مصفوفة الأدراج
  if (doc.containsKey("drawers")) {
    JsonArray drawers = doc["drawers"];
    byte ledData = 0b00000000; // متغير تجميع الليدات

    // المرور على الأدراج المطلوبة (من 1 لـ 6) واختيار البت المناسبة
    for (int i = 0; i < drawers.size(); i++) {
      int drawerNum = drawers[i];
      if (drawerNum >= 1 && drawerNum <= 6) { 
        ledData |= (1 << (drawerNum - 1));
      }
    }

    // 1. تحديث إضاءة الليدات فوراً
    updateShiftRegister(ledData);
    
    // الرد على الأبليكيشن بنجاح العملية
    server.send(200, "application/json", "{\"status\":\"success\",\"message\":\"Drawers updated\"}");
    
    // 2. تشغيل البازر كـ تنبيه صوتي فقط إذا كانت المصفوفة تحتوي على أدراج (ليست عملية إطفاء)
    if (drawers.size() > 0) {
      triggerBuzzer();
    }
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing drawers array\"}");
  }
}

// دالة إرسال البيانات للـ Shift Register مع الحفاظ على التوقيت المستقر ميكروسوفتياً
void updateShiftRegister(byte data) {
  digitalWrite(latchPin, LOW);
  delayMicroseconds(5);
  shiftOut(dataPin, clockPin, MSBFIRST, data);
  delayMicroseconds(5);
  digitalWrite(latchPin, HIGH);
}

// دالة تشغيل صوت تنبيه البازر
// دالة تشغيل صوت تنبيه البازر — رنين متقطع
void triggerBuzzer() {
  for (int i = 0; i < 100; i++) {   // 100 نبضات
    digitalWrite(buzzerPin, HIGH);
    delay(150);                     // شغال 300ms
    digitalWrite(buzzerPin, LOW);
    delay(100);                     // صامت 200ms
  }
}