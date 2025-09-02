#include "CelestialPanel.h"

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== Celestial Bridge Panel System ===");
    Serial.printf("Panel ID: %s\n", PANEL_ID);
    Serial.printf("Station: %s\n", STATION);
    Serial.printf("Version: %s\n", VERSION);
    Serial.printf("ESP32 Chip ID: %llX\n", ESP.getEfuseMac());
    Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.println("=====================================");
    
    if (!panel.begin()) {
        Serial.println("Panel initialization failed!");
        Serial.println("Entering error mode...");
        
        while (true) {
            digitalWrite(LED_BUILTIN, HIGH);
            delay(100);
            digitalWrite(LED_BUILTIN, LOW);
            delay(100);
        }
    }
    
    Serial.println("Panel system ready!");
    pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
    panel.loop();
    
    static unsigned long lastStatusLed = 0;
    if (millis() - lastStatusLed > 1000) {
        if (panel.isConnected()) {
            digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
        } else {
            digitalWrite(LED_BUILTIN, LOW);
        }
        lastStatusLed = millis();
    }
    
    static unsigned long lastMemoryCheck = 0;
    if (millis() - lastMemoryCheck > 30000) {
        Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
        lastMemoryCheck = millis();
    }
}