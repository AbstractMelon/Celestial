#include "CelestialPanel.h"

CelestialPanel panel;

CelestialPanel::CelestialPanel() : jsonDoc(JSON_BUFFER_SIZE) {
    strcpy(panelInfo.panelId, PANEL_ID);
    strcpy(panelInfo.station, STATION);
    panelInfo.status = STATUS_OFFLINE;
    panelInfo.lastHeartbeat = 0;
    panelInfo.deviceCount = 0;
    panelInfo.errorCount = 0;
    
    deviceCount = 0;
    lastHeartbeat = 0;
    lastReconnectAttempt = 0;
    configReceived = false;
    
    for (int i = 0; i < MAX_DEVICES; i++) {
        inputDevices[i] = nullptr;
        outputDevices[i] = nullptr;
        devices[i].enabled = false;
    }
    
    strcpy(networkConfig.ssid, "Celestial_Bridge");
    strcpy(networkConfig.password, "starship2024");
    strcpy(networkConfig.serverHost, "192.168.1.100");
    networkConfig.serverPort = 8081;
}

CelestialPanel::~CelestialPanel() {
    for (int i = 0; i < MAX_DEVICES; i++) {
        if (inputDevices[i]) delete inputDevices[i];
        if (outputDevices[i]) delete outputDevices[i];
    }
}

bool CelestialPanel::begin() {
    Serial.begin(115200);
    Serial.println("Celestial Panel Starting...");
    Serial.printf("Panel ID: %s\n", panelInfo.panelId);
    Serial.printf("Station: %s\n", panelInfo.station);
    Serial.printf("Version: %s\n", VERSION);
    
    panelInfo.status = STATUS_CONNECTING;
    initWiFi();
    
    if (WiFi.status() == WL_CONNECTED) {
        initTCP();
        return true;
    }
    
    panelInfo.status = STATUS_ERROR;
    addError("WiFi connection failed");
    return false;
}

void CelestialPanel::loop() {
    static unsigned long lastWatchdog = 0;
    
    if (millis() - lastWatchdog > WATCHDOG_TIMEOUT_MS) {
        watchdogReset();
        lastWatchdog = millis();
    }
    
    if (WiFi.status() != WL_CONNECTED) {
        panelInfo.status = STATUS_ERROR;
        addError("WiFi disconnected");
        reconnect();
        return;
    }
    
    if (!tcpClient.connected()) {
        panelInfo.status = STATUS_CONNECTING;
        reconnect();
        return;
    }
    
    while (tcpClient.available()) {
        char c = tcpClient.read();
        if (c == '\n') {
            processMessage(messageBuffer);
            messageBuffer = "";
        } else {
            messageBuffer += c;
        }
    }
    
    if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL_MS) {
        sendHeartbeat();
        lastHeartbeat = millis();
    }
    
    if (configReceived) {
        updateInputDevices();
        updateOutputDevices();
    }
    
    delay(10);
}

void CelestialPanel::initWiFi() {
    Serial.printf("Connecting to WiFi: %s\n", networkConfig.ssid);
    WiFi.begin(networkConfig.ssid, networkConfig.password);
    
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startTime < WIFI_TIMEOUT_MS) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("WiFi connected: %s\n", WiFi.localIP().toString().c_str());
        clearErrors();
    } else {
        Serial.println("WiFi connection failed");
        addError("WiFi timeout");
    }
}

void CelestialPanel::initTCP() {
    Serial.printf("Connecting to server: %s:%d\n", networkConfig.serverHost, networkConfig.serverPort);
    
    if (tcpClient.connect(networkConfig.serverHost, networkConfig.serverPort)) {
        Serial.println("TCP connected");
        panelInfo.status = STATUS_CONFIGURING;
        sendHeartbeat();
    } else {
        Serial.println("TCP connection failed");
        addError("Server unreachable");
    }
}

void CelestialPanel::sendHeartbeat() {
    jsonDoc.clear();
    jsonDoc["type"] = "panel_heartbeat";
    jsonDoc["timestamp"] = getCurrentTimestamp();
    
    JsonObject data = jsonDoc.createNestedObject("data");
    data["client_id"] = panelInfo.panelId;
    data["ping"] = getCurrentTimestamp();
    
    String message;
    serializeJson(jsonDoc, message);
    message += "\n";
    
    tcpClient.print(message);
    Serial.printf("Heartbeat sent: %s\n", panelInfo.panelId);
}

void CelestialPanel::sendStatus() {
    jsonDoc.clear();
    jsonDoc["type"] = "panel_status";
    jsonDoc["timestamp"] = getCurrentTimestamp();
    
    JsonObject data = jsonDoc.createNestedObject("data");
    data["panel_id"] = panelInfo.panelId;
    
    switch (panelInfo.status) {
        case STATUS_ONLINE: data["status"] = "online"; break;
        case STATUS_OFFLINE: data["status"] = "offline"; break;
        case STATUS_ERROR: data["status"] = "error"; break;
        case STATUS_PARTIAL: data["status"] = "partial"; break;
        default: data["status"] = "connecting"; break;
    }
    
    data["last_seen"] = getCurrentTimestamp();
    data["device_count"] = deviceCount;
    
    if (panelInfo.errorCount > 0) {
        JsonArray errors = data.createNestedArray("errors");
        for (int i = 0; i < panelInfo.errorCount; i++) {
            errors.add(panelInfo.errors[i]);
        }
    }
    
    String message;
    serializeJson(jsonDoc, message);
    message += "\n";
    
    tcpClient.print(message);
}

void CelestialPanel::sendInput(const char* deviceId, float value, JsonObject context) {
    jsonDoc.clear();
    jsonDoc["type"] = "panel_input";
    jsonDoc["timestamp"] = getCurrentTimestamp();
    
    JsonObject data = jsonDoc.createNestedObject("data");
    data["panel_id"] = panelInfo.panelId;
    data["device_id"] = deviceId;
    data["value"] = value;
    
    if (!context.isNull()) {
        data["context"] = context;
    }
    
    String message;
    serializeJson(jsonDoc, message);
    message += "\n";
    
    tcpClient.print(message);
}

void CelestialPanel::processMessage(const String& message) {
    jsonDoc.clear();
    DeserializationError error = deserializeJson(jsonDoc, message);
    
    if (error) {
        Serial.printf("JSON parse error: %s\n", error.c_str());
        return;
    }
    
    String type = jsonDoc["type"];
    
    if (type == "panel_config") {
        handleConfiguration(jsonDoc["data"]);
    } else if (type == "panel_output") {
        handleOutputCommand(jsonDoc["data"]);
    } else if (type == "panel_heartbeat") {
        Serial.println("Heartbeat acknowledged");
    }
}

void CelestialPanel::handleConfiguration(JsonObject data) {
    Serial.println("Received configuration");
    
    String panelId = data["panel_id"];
    if (panelId != panelInfo.panelId) {
        Serial.printf("Config mismatch: expected %s, got %s\n", panelInfo.panelId, panelId.c_str());
        return;
    }
    
    strcpy(panelInfo.name, data["name"] | "Unknown Panel");
    
    JsonArray deviceArray = data["devices"];
    deviceCount = 0;
    
    for (JsonObject deviceObj : deviceArray) {
        if (deviceCount >= MAX_DEVICES) break;
        
        DeviceConfig& device = devices[deviceCount];
        strcpy(device.id, deviceObj["id"]);
        device.type = parseDeviceType(deviceObj["type"]);
        device.pin = deviceObj["pin"];
        device.config = deviceObj["config"];
        device.enabled = false;
        device.lastUpdate = 0;
        device.lastValue = 0;
        device.hasChanged = false;
        
        if (device.type == DEVICE_UNKNOWN) {
            Serial.printf("Unknown device type for %s\n", device.id);
            continue;
        }
        
        if (device.type <= DEVICE_SLIDER) {
            inputDevices[deviceCount] = createInputDevice(device.type);
            if (inputDevices[deviceCount] && inputDevices[deviceCount]->begin(device.pin, device.config)) {
                device.enabled = true;
                Serial.printf("Input device %s initialized on pin %d\n", device.id, device.pin);
            } else {
                Serial.printf("Failed to initialize input device %s\n", device.id);
                addError(String("Input device ") + device.id + " failed");
            }
        } else {
            outputDevices[deviceCount] = createOutputDevice(device.type);
            if (outputDevices[deviceCount] && outputDevices[deviceCount]->begin(device.pin, device.config)) {
                device.enabled = true;
                Serial.printf("Output device %s initialized on pin %d\n", device.id, device.pin);
            } else {
                Serial.printf("Failed to initialize output device %s\n", device.id);
                addError(String("Output device ") + device.id + " failed");
            }
        }
        
        deviceCount++;
    }
    
    configReceived = true;
    panelInfo.status = (panelInfo.errorCount == 0) ? STATUS_ONLINE : STATUS_PARTIAL;
    sendStatus();
    
    Serial.printf("Configuration complete: %d devices\n", deviceCount);
}

void CelestialPanel::handleOutputCommand(JsonObject data) {
    String panelId = data["panel_id"];
    if (panelId != panelInfo.panelId) return;
    
    String deviceId = data["device_id"];
    String command = data["command"];
    JsonVariant value = data["value"];
    JsonObject context = data["context"];
    
    for (int i = 0; i < deviceCount; i++) {
        if (devices[i].enabled && strcmp(devices[i].id, deviceId.c_str()) == 0) {
            if (outputDevices[i]) {
                if (command == "set_value") {
                    outputDevices[i]->setValue(value.as<float>());
                } else {
                    outputDevices[i]->setCommand(command.c_str(), value);
                }
            }
            break;
        }
    }
}

void CelestialPanel::updateInputDevices() {
    for (int i = 0; i < deviceCount; i++) {
        if (!devices[i].enabled || !inputDevices[i]) continue;
        
        inputDevices[i]->update();
        
        if (inputDevices[i]->hasChanged()) {
            float value = inputDevices[i]->read();
            devices[i].lastValue = value;
            devices[i].lastUpdate = millis();
            
            JsonObject context = jsonDoc.createNestedObject();
            context["raw_value"] = value;
            context["calibrated"] = true;
            
            sendInput(devices[i].id, value, context);
        }
    }
}

void CelestialPanel::updateOutputDevices() {
    for (int i = 0; i < deviceCount; i++) {
        if (!devices[i].enabled || !outputDevices[i]) continue;
        outputDevices[i]->update();
    }
}

void CelestialPanel::addError(const String& error) {
    if (panelInfo.errorCount < 8) {
        panelInfo.errors[panelInfo.errorCount] = error;
        panelInfo.errorCount++;
    }
    Serial.printf("Error: %s\n", error.c_str());
}

void CelestialPanel::clearErrors() {
    panelInfo.errorCount = 0;
}

DeviceType CelestialPanel::parseDeviceType(const char* typeStr) {
    if (strcmp(typeStr, "button") == 0) return DEVICE_BUTTON;
    if (strcmp(typeStr, "potentiometer") == 0) return DEVICE_POTENTIOMETER;
    if (strcmp(typeStr, "encoder") == 0) return DEVICE_ENCODER;
    if (strcmp(typeStr, "rotary_switch") == 0) return DEVICE_ROTARY_SWITCH;
    if (strcmp(typeStr, "slider") == 0) return DEVICE_SLIDER;
    if (strcmp(typeStr, "led") == 0) return DEVICE_LED;
    if (strcmp(typeStr, "rgb_strip") == 0) return DEVICE_RGB_STRIP;
    if (strcmp(typeStr, "7segment") == 0) return DEVICE_7SEGMENT;
    if (strcmp(typeStr, "led_bar") == 0) return DEVICE_LED_BAR;
    if (strcmp(typeStr, "buzzer") == 0) return DEVICE_BUZZER;
    return DEVICE_UNKNOWN;
}

InputDevice* CelestialPanel::createInputDevice(DeviceType type) {
    switch (type) {
        case DEVICE_BUTTON: return new ButtonDevice();
        case DEVICE_POTENTIOMETER: return new PotentiometerDevice();
        case DEVICE_ENCODER: return new EncoderDevice();
        case DEVICE_ROTARY_SWITCH: return new RotarySwitchDevice();
        case DEVICE_SLIDER: return new SliderDevice();
        default: return nullptr;
    }
}

OutputDevice* CelestialPanel::createOutputDevice(DeviceType type) {
    switch (type) {
        case DEVICE_LED: return new LEDDevice();
        case DEVICE_RGB_STRIP: return new RGBStripDevice();
        case DEVICE_7SEGMENT: return new SevenSegmentDevice();
        case DEVICE_LED_BAR: return new LEDBarDevice();
        case DEVICE_BUZZER: return new BuzzerDevice();
        default: return nullptr;
    }
}

String CelestialPanel::getCurrentTimestamp() {
    return String(millis());
}

void CelestialPanel::reconnect() {
    if (millis() - lastReconnectAttempt < RECONNECT_DELAY_MS) return;
    
    lastReconnectAttempt = millis();
    Serial.println("Attempting reconnection...");
    
    if (WiFi.status() != WL_CONNECTED) {
        initWiFi();
    }
    
    if (WiFi.status() == WL_CONNECTED && !tcpClient.connected()) {
        initTCP();
    }
}

void CelestialPanel::watchdogReset() {
    Serial.println("Watchdog reset");
}

void CelestialPanel::setNetworkConfig(const char* ssid, const char* password, const char* host, uint16_t port) {
    strcpy(networkConfig.ssid, ssid);
    strcpy(networkConfig.password, password);
    strcpy(networkConfig.serverHost, host);
    networkConfig.serverPort = port;
}

void CelestialPanel::enableWatchdog(bool enable) {
    if (enable) {
        esp_task_wdt_init(WATCHDOG_TIMEOUT_MS / 1000, true);
        esp_task_wdt_add(NULL);
    }
}

bool ButtonDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->pullup = config["pullup"] | true;
    this->debounceMs = config["debounce_ms"] | DEBOUNCE_DELAY_MS;
    
    pinMode(pin, pullup ? INPUT_PULLUP : INPUT);
    lastState = digitalRead(pin);
    currentState = lastState;
    lastDebounce = 0;
    hasChangedFlag = false;
    
    return true;
}

float ButtonDevice::read() {
    return currentState ? 1.0f : 0.0f;
}

bool ButtonDevice::hasChanged() {
    bool changed = hasChangedFlag;
    hasChangedFlag = false;
    return changed;
}

void ButtonDevice::update() {
    bool reading = digitalRead(pin);
    
    if (reading != lastState) {
        lastDebounce = millis();
    }
    
    if ((millis() - lastDebounce) > debounceMs) {
        if (reading != currentState) {
            currentState = reading;
            hasChangedFlag = true;
        }
    }
    
    lastState = reading;
}

bool PotentiometerDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->minVal = config["min"] | 0;
    this->maxVal = config["max"] | 1023;
    this->deadzone = config["deadzone"] | 10;
    this->invert = config["invert"] | false;
    this->smoothing = config["smoothing"] | ANALOG_SMOOTHING;
    
    pinMode(pin, INPUT);
    rawValue = analogRead(pin);
    smoothedValue = rawValue;
    lastReportedValue = smoothedValue;
    hasChangedFlag = false;
    
    return true;
}

float PotentiometerDevice::read() {
    float normalized = (smoothedValue - minVal) / (float)(maxVal - minVal);
    return invert ? 1.0f - normalized : normalized;
}

bool PotentiometerDevice::hasChanged() {
    bool changed = hasChangedFlag;
    hasChangedFlag = false;
    return changed;
}

void PotentiometerDevice::update() {
    rawValue = analogRead(pin);
    smoothedValue = smoothedValue * (1.0f - smoothing) + rawValue * smoothing;
    
    if (abs(smoothedValue - lastReportedValue) > deadzone) {
        lastReportedValue = smoothedValue;
        hasChangedFlag = true;
    }
}

bool LEDDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->pwmEnabled = config["pwm"] | true;
    this->maxBrightness = config["max_brightness"] | 255;
    this->currentBrightness = 0;
    this->currentState = false;
    this->blinking = false;
    
    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);
    
    if (pwmEnabled) {
        ledcSetup(pin, 5000, 8);
        ledcAttachPin(pin, pin);
    }
    
    return true;
}

bool LEDDevice::setValue(float value) {
    currentBrightness = (uint8_t)(value * maxBrightness);
    currentState = currentBrightness > 0;
    
    if (pwmEnabled) {
        ledcWrite(pin, currentBrightness);
    } else {
        digitalWrite(pin, currentState ? HIGH : LOW);
    }
    
    return true;
}

bool LEDDevice::setCommand(const char* command, JsonVariant value) {
    if (strcmp(command, "set_brightness") == 0) {
        return setValue(value.as<float>() / 255.0f);
    } else if (strcmp(command, "set_state") == 0) {
        return setValue(value.as<bool>() ? 1.0f : 0.0f);
    } else if (strcmp(command, "blink") == 0) {
        JsonObject params = value.as<JsonObject>();
        blinkRate = params["rate"] | 500;
        blinkDuration = params["duration"] | 5000;
        blinking = true;
        blinkStart = millis();
        return true;
    }
    
    return false;
}

void LEDDevice::update() {
    if (blinking) {
        if (millis() - blinkStart > blinkDuration) {
            blinking = false;
            setValue(0);
        } else {
            bool state = ((millis() - blinkStart) / blinkRate) % 2 == 0;
            setValue(state ? 1.0f : 0.0f);
        }
    }
}

bool RGBStripDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->pixels = config["pixels"] | 12;
    this->maxBrightness = config["max_brightness"] | 128;
    this->stripType = config["type"] | "WS2812B";
    
    leds = new CRGB[pixels];
    FastLED.addLeds<WS2812B, pin, GRB>(leds, pixels);
    FastLED.setBrightness(maxBrightness);
    FastLED.clear();
    FastLED.show();
    
    patternActive = false;
    
    return true;
}

bool RGBStripDevice::setValue(float value) {
    uint8_t brightness = (uint8_t)(value * 255);
    fill_solid(leds, pixels, CRGB(brightness, brightness, brightness));
    FastLED.show();
    return true;
}

bool RGBStripDevice::setCommand(const char* command, JsonVariant value) {
    if (strcmp(command, "set_all") == 0) {
        JsonArray color = value.as<JsonArray>();
        if (color.size() >= 3) {
            CRGB rgb(color[0], color[1], color[2]);
            fill_solid(leds, pixels, rgb);
            FastLED.show();
        }
        return true;
    } else if (strcmp(command, "set_colors") == 0) {
        JsonArray colors = value.as<JsonArray>();
        for (int i = 0; i < pixels && i < colors.size(); i++) {
            JsonArray color = colors[i];
            if (color.size() >= 3) {
                leds[i] = CRGB(color[0], color[1], color[2]);
            }
        }
        FastLED.show();
        return true;
    }
    
    return false;
}

void RGBStripDevice::update() {
    if (patternActive) {
        // Pattern animation logic would go here
    }
}

bool SevenSegmentDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->digits = config["digits"] | 4;
    this->driver = config["driver"] | "MAX7219";
    this->brightness = config["brightness"] | 8;
    
    for (int i = 0; i < 8; i++) {
        decimalPoints[i] = false;
    }
    
    return true;
}

bool SevenSegmentDevice::setValue(float value) {
    displayText = String((int)value);
    return true;
}

bool SevenSegmentDevice::setCommand(const char* command, JsonVariant value) {
    if (strcmp(command, "set_text") == 0) {
        displayText = value.as<String>();
        return true;
    } else if (strcmp(command, "set_brightness") == 0) {
        brightness = value.as<uint8_t>();
        return true;
    } else if (strcmp(command, "set_decimal") == 0) {
        JsonObject params = value.as<JsonObject>();
        int pos = params["position"];
        bool state = params["state"];
        if (pos >= 0 && pos < 8) {
            decimalPoints[pos] = state;
        }
        return true;
    }
    
    return false;
}

void SevenSegmentDevice::update() {
    // 7-segment display update logic would go here
}

bool LEDBarDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->ledCount = config["leds"] | 10;
    this->horizontal = config["orientation"] == "horizontal";
    this->color = config["color"] | "green";
    this->currentLevel = 0.0f;
    
    ledStates = new bool[ledCount];
    for (int i = 0; i < ledCount; i++) {
        ledStates[i] = false;
    }
    
    return true;
}

bool LEDBarDevice::setValue(float value) {
    currentLevel = constrain(value, 0.0f, 1.0f);
    int activeLeds = (int)(currentLevel * ledCount);
    
    for (int i = 0; i < ledCount; i++) {
        ledStates[i] = i < activeLeds;
    }
    
    return true;
}

bool LEDBarDevice::setCommand(const char* command, JsonVariant value) {
    if (strcmp(command, "set_level") == 0) {
        return setValue(value.as<float>());
    } else if (strcmp(command, "set_pattern") == 0) {
        JsonArray pattern = value.as<JsonArray>();
        for (int i = 0; i < ledCount && i < pattern.size(); i++) {
            ledStates[i] = pattern[i];
        }
        return true;
    }
    
    return false;
}

void LEDBarDevice::update() {
    // LED bar display update logic would go here
}

bool BuzzerDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->frequency = config["frequency"] | 440;
    this->maxVolume = config["max_volume"] | 128;
    this->isPlaying = false;
    
    pinMode(pin, OUTPUT);
    
    return true;
}

bool BuzzerDevice::setValue(float value) {
    if (value > 0) {
        tone(pin, frequency);
        isPlaying = true;
    } else {
        noTone(pin);
        isPlaying = false;
    }
    
    return true;
}

bool BuzzerDevice::setCommand(const char* command, JsonVariant value) {
    if (strcmp(command, "set_buzzer") == 0) {
        JsonObject params = value.as<JsonObject>();
        frequency = params["frequency"] | 440;
        playDuration = params["duration"] | 1000;
        
        tone(pin, frequency);
        isPlaying = true;
        playStart = millis();
        
        return true;
    }
    
    return false;
}

void BuzzerDevice::update() {
    if (isPlaying && millis() - playStart > playDuration) {
        noTone(pin);
        isPlaying = false;
    }
}

bool EncoderDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->steps = config["steps"] | 100;
    this->clockwise = config["direction"] == "clockwise";
    this->acceleration = config["acceleration"] | false;
    
    if (config.containsKey("button_pin")) {
        this->buttonPin = config["button_pin"];
        this->hasButtonPin = true;
        pinMode(buttonPin, INPUT_PULLUP);
    } else {
        this->hasButtonPin = false;
    }
    
    pinMode(pin, INPUT_PULLUP);
    position = 0;
    buttonState = false;
    lastButtonState = false;
    hasChangedFlag = false;
    
    return true;
}

float EncoderDevice::read() {
    return (float)position / steps;
}

bool EncoderDevice::hasChanged() {
    bool changed = hasChangedFlag;
    hasChangedFlag = false;
    return changed;
}

void EncoderDevice::update() {
    // Basic encoder logic - would need interrupt-based implementation for accuracy
    static bool lastA = false;
    bool currentA = digitalRead(pin);
    
    if (currentA != lastA) {
        position += clockwise ? 1 : -1;
        hasChangedFlag = true;
    }
    lastA = currentA;
    
    if (hasButtonPin) {
        bool currentButton = !digitalRead(buttonPin);
        if (currentButton != lastButtonState) {
            buttonState = currentButton;
            lastButtonState = currentButton;
            hasChangedFlag = true;
        }
    }
}

bool RotarySwitchDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->positions = config["positions"] | 8;
    this->currentPosition = config["starting_position"] | 0;
    this->lastPosition = currentPosition;
    this->hasChangedFlag = false;
    
    pinMode(pin, INPUT);
    
    return true;
}

float RotarySwitchDevice::read() {
    return (float)currentPosition;
}

bool RotarySwitchDevice::hasChanged() {
    bool changed = hasChangedFlag;
    hasChangedFlag = false;
    return changed;
}

void RotarySwitchDevice::update() {
    int rawValue = analogRead(pin);
    uint8_t newPosition = map(rawValue, 0, 1023, 0, positions - 1);
    
    if (newPosition != currentPosition) {
        currentPosition = newPosition;
        hasChangedFlag = true;
    }
}

bool SliderDevice::begin(uint8_t pin, JsonObject config) {
    this->pin = pin;
    this->minVal = config["min"] | 0;
    this->maxVal = config["max"] | 1023;
    this->vertical = config["orientation"] == "vertical";
    this->centerDetent = config["center_detent"] | false;
    
    pinMode(pin, INPUT);
    rawValue = analogRead(pin);
    smoothedValue = rawValue;
    lastReportedValue = smoothedValue;
    hasChangedFlag = false;
    
    return true;
}

float SliderDevice::read() {
    float normalized = (smoothedValue - minVal) / (float)(maxVal - minVal);
    return constrain(normalized, 0.0f, 1.0f);
}

bool SliderDevice::hasChanged() {
    bool changed = hasChangedFlag;
    hasChangedFlag = false;
    return changed;
}

void SliderDevice::update() {
    rawValue = analogRead(pin);
    smoothedValue = smoothedValue * 0.9f + rawValue * 0.1f;
    
    if (abs(smoothedValue - lastReportedValue) > 10) {
        lastReportedValue = smoothedValue;
        hasChangedFlag = true;
    }
}