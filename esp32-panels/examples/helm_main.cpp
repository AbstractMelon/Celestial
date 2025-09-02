#include "CelestialPanel.h"

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== Helm Main Panel ===");
    
    panel.setNetworkConfig(
        "Celestial_Bridge",
        "starship2024", 
        "192.168.1.100",
        8081
    );
    
    if (!panel.begin()) {
        Serial.println("Helm panel initialization failed!");
        while (true) {
            digitalWrite(LED_BUILTIN, HIGH);
            delay(200);
            digitalWrite(LED_BUILTIN, LOW);
            delay(200);
        }
    }
    
    Serial.println("Helm panel ready!");
    pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
    panel.loop();
    
    static unsigned long lastHeartbeat = 0;
    if (millis() - lastHeartbeat > 2000) {
        if (panel.isConnected()) {
            digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
        } else {
            for (int i = 0; i < 3; i++) {
                digitalWrite(LED_BUILTIN, HIGH);
                delay(100);
                digitalWrite(LED_BUILTIN, LOW);
                delay(100);
            }
        }
        lastHeartbeat = millis();
    }
}