#ifndef CELESTIAL_PANEL_H
#define CELESTIAL_PANEL_H

#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <Wire.h>
#include <SPI.h>

#define VERSION "1.0.0"
#define MAX_DEVICES 32
#define JSON_BUFFER_SIZE 2048
#define WIFI_TIMEOUT_MS 30000
#define TCP_TIMEOUT_MS 5000
#define HEARTBEAT_INTERVAL_MS 10000
#define RECONNECT_DELAY_MS 5000
#define DEBOUNCE_DELAY_MS 50
#define ANALOG_SMOOTHING 0.1f
#define WATCHDOG_TIMEOUT_MS 60000

#ifndef PANEL_ID
#define PANEL_ID "unknown_panel"
#endif

#ifndef STATION
#define STATION "unknown"
#endif

enum DeviceType {
    DEVICE_BUTTON,
    DEVICE_POTENTIOMETER,
    DEVICE_ENCODER,
    DEVICE_ROTARY_SWITCH,
    DEVICE_SLIDER,
    DEVICE_LED,
    DEVICE_RGB_STRIP,
    DEVICE_7SEGMENT,
    DEVICE_LED_BAR,
    DEVICE_BUZZER,
    DEVICE_UNKNOWN
};

enum PanelStatus {
    STATUS_OFFLINE,
    STATUS_CONNECTING,
    STATUS_CONFIGURING,
    STATUS_ONLINE,
    STATUS_ERROR,
    STATUS_PARTIAL
};

enum MessageType {
    MSG_PANEL_HEARTBEAT,
    MSG_PANEL_STATUS,
    MSG_PANEL_INPUT,
    MSG_PANEL_CONFIG,
    MSG_PANEL_OUTPUT,
    MSG_UNKNOWN
};

struct DeviceConfig {
    char id[32];
    DeviceType type;
    uint8_t pin;
    JsonObject config;
    bool enabled;
    unsigned long lastUpdate;
    float lastValue;
    bool hasChanged;
};

struct NetworkConfig {
    char ssid[32];
    char password[64];
    char serverHost[32];
    uint16_t serverPort;
};

struct PanelInfo {
    char panelId[32];
    char station[16];
    char name[64];
    PanelStatus status;
    unsigned long lastHeartbeat;
    uint8_t deviceCount;
    String errors[8];
    uint8_t errorCount;
};

class InputDevice {
public:
    virtual ~InputDevice() {}
    virtual bool begin(uint8_t pin, JsonObject config) = 0;
    virtual float read() = 0;
    virtual bool hasChanged() = 0;
    virtual void update() = 0;
    virtual const char* getType() = 0;
};

class OutputDevice {
public:
    virtual ~OutputDevice() {}
    virtual bool begin(uint8_t pin, JsonObject config) = 0;
    virtual bool setValue(float value) = 0;
    virtual bool setCommand(const char* command, JsonVariant value) = 0;
    virtual void update() = 0;
    virtual const char* getType() = 0;
};

class ButtonDevice : public InputDevice {
private:
    uint8_t pin;
    bool pullup;
    bool lastState;
    bool currentState;
    unsigned long lastDebounce;
    uint16_t debounceMs;
    bool hasChangedFlag;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "button"; }
};

class PotentiometerDevice : public InputDevice {
private:
    uint8_t pin;
    int minVal, maxVal;
    int deadzone;
    bool invert;
    float smoothing;
    float rawValue;
    float smoothedValue;
    float lastReportedValue;
    bool hasChangedFlag;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "potentiometer"; }
};

class EncoderDevice : public InputDevice {
private:
    uint8_t pin;
    uint8_t buttonPin;
    int steps;
    bool clockwise;
    bool acceleration;
    volatile int position;
    bool buttonState;
    bool lastButtonState;
    bool hasChangedFlag;
    bool hasButtonPin;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "encoder"; }
    bool getButtonState() { return buttonState; }
};

class RotarySwitchDevice : public InputDevice {
private:
    uint8_t pin;
    uint8_t positions;
    uint8_t currentPosition;
    uint8_t lastPosition;
    bool hasChangedFlag;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "rotary_switch"; }
};

class SliderDevice : public InputDevice {
private:
    uint8_t pin;
    int minVal, maxVal;
    bool vertical;
    bool centerDetent;
    float rawValue;
    float smoothedValue;
    float lastReportedValue;
    bool hasChangedFlag;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "slider"; }
};

class LEDDevice : public OutputDevice {
private:
    uint8_t pin;
    bool pwmEnabled;
    uint8_t maxBrightness;
    uint8_t currentBrightness;
    bool currentState;
    bool blinking;
    unsigned long blinkStart;
    uint16_t blinkRate;
    uint16_t blinkDuration;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    bool setValue(float value) override;
    bool setCommand(const char* command, JsonVariant value) override;
    void update() override;
    const char* getType() override { return "led"; }
};

class RGBStripDevice : public OutputDevice {
private:
    uint8_t pin;
    uint16_t pixels;
    uint8_t maxBrightness;
    CRGB* leds;
    String stripType;
    bool patternActive;
    unsigned long patternStart;
    String currentPattern;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    bool setValue(float value) override;
    bool setCommand(const char* command, JsonVariant value) override;
    void update() override;
    const char* getType() override { return "rgb_strip"; }
};

class SevenSegmentDevice : public OutputDevice {
private:
    uint8_t pin;
    uint8_t digits;
    String driver;
    uint8_t brightness;
    String displayText;
    bool decimalPoints[8];

public:
    bool begin(uint8_t pin, JsonObject config) override;
    bool setValue(float value) override;
    bool setCommand(const char* command, JsonVariant value) override;
    void update() override;
    const char* getType() override { return "7segment"; }
};

class LEDBarDevice : public OutputDevice {
private:
    uint8_t pin;
    uint8_t ledCount;
    bool horizontal;
    String color;
    float currentLevel;
    bool* ledStates;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    bool setValue(float value) override;
    bool setCommand(const char* command, JsonVariant value) override;
    void update() override;
    const char* getType() override { return "led_bar"; }
};

class BuzzerDevice : public OutputDevice {
private:
    uint8_t pin;
    uint16_t frequency;
    uint8_t maxVolume;
    bool isPlaying;
    unsigned long playStart;
    uint16_t playDuration;

public:
    bool begin(uint8_t pin, JsonObject config) override;
    bool setValue(float value) override;
    bool setCommand(const char* command, JsonVariant value) override;
    void update() override;
    const char* getType() override { return "buzzer"; }
};

class CelestialPanel {
private:
    WiFiClient tcpClient;
    PanelInfo panelInfo;
    NetworkConfig networkConfig;
    DeviceConfig devices[MAX_DEVICES];
    InputDevice* inputDevices[MAX_DEVICES];
    OutputDevice* outputDevices[MAX_DEVICES];
    uint8_t deviceCount;
    
    unsigned long lastHeartbeat;
    unsigned long lastReconnectAttempt;
    bool configReceived;
    
    String messageBuffer;
    DynamicJsonDocument jsonDoc;
    
    void initWiFi();
    void initTCP();
    void sendHeartbeat();
    void sendStatus();
    void sendInput(const char* deviceId, float value, JsonObject context = JsonObject());
    void processMessage(const String& message);
    void handleConfiguration(JsonObject data);
    void handleOutputCommand(JsonObject data);
    void updateInputDevices();
    void updateOutputDevices();
    void addError(const String& error);
    void clearErrors();
    DeviceType parseDeviceType(const char* typeStr);
    InputDevice* createInputDevice(DeviceType type);
    OutputDevice* createOutputDevice(DeviceType type);
    String getCurrentTimestamp();
    void reconnect();
    void watchdogReset();

public:
    CelestialPanel();
    ~CelestialPanel();
    
    bool begin();
    void loop();
    void setNetworkConfig(const char* ssid, const char* password, const char* host, uint16_t port);
    PanelStatus getStatus() { return panelInfo.status; }
    const char* getPanelId() { return panelInfo.panelId; }
    bool isConnected() { return tcpClient.connected(); }
    uint8_t getDeviceCount() { return deviceCount; }
    void enableWatchdog(bool enable);
};

extern CelestialPanel panel;

#endif