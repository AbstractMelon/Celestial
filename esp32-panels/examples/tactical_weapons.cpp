#include "CelestialPanel.h"

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== Tactical Weapons Panel ===");
    
    panel.setNetworkConfig(
        "Celestial_Bridge",
        "starship2024", 
        "192.168.1.100",
        8081
    );
    
    if (!panel.begin()) {
        Serial.println("Tactical weapons panel initialization failed!");
        while (true) {
            digitalWrite(LED_BUILTIN, HIGH);
            delay(300);
            digitalWrite(LED_BUILTIN, LOW);
            delay(100);
            digitalWrite(LED_BUILTIN, HIGH);
            delay(100);
            digitalWrite(LED_BUILTIN, LOW);
            delay(100);
        }
    }
    
    Serial.println("Tactical weapons panel ready!");
    pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
    panel.loop();
    
    static unsigned long lastStatusUpdate = 0;
    if (millis() - lastStatusUpdate > 1500) {
        if (panel.isConnected()) {
            digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
        } else {
            for (int i = 0; i < 5; i++) {
                digitalWrite(LED_BUILTIN, HIGH);
                delay(50);
                digitalWrite(LED_BUILTIN, LOW);
                delay(50);
            }
        }
        lastStatusUpdate = millis();
    }
}