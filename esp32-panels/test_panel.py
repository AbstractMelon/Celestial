#!/usr/bin/env python3
"""
Celestial ESP32 Panel Test Utility

This script provides automated testing and diagnostics for ESP32 control panels.
It can test individual devices, full panel functionality, and communication
with the backend server.
"""

import json
import socket
import time
import threading
import argparse
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any

class PanelTester:
    def __init__(self, server_host: str = "127.0.0.1", server_port: int = 8081):
        self.server_host = server_host
        self.server_port = server_port
        self.socket = None
        self.connected = False
        self.message_buffer = ""
        self.received_messages = []
        self.test_results = []

    def connect(self) -> bool:
        """Connect to the Celestial backend server"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(10)
            self.socket.connect((self.server_host, self.server_port))
            self.connected = True
            print(f" Connected to server {self.server_host}:{self.server_port}")

            # Start message receiver thread
            receiver_thread = threading.Thread(target=self._message_receiver, daemon=True)
            receiver_thread.start()

            return True
        except Exception as e:
            print(f"Failed to connect to server: {e}")
            return False

    def disconnect(self):
        """Disconnect from server"""
        if self.socket:
            self.socket.close()
        self.connected = False
        print(" Disconnected from server")

    def _message_receiver(self):
        """Background thread to receive messages from server"""
        while self.connected:
            try:
                data = self.socket.recv(1024).decode('utf-8')
                if not data:
                    break

                self.message_buffer += data
                while '\n' in self.message_buffer:
                    line, self.message_buffer = self.message_buffer.split('\n', 1)
                    if line.strip():
                        try:
                            message = json.loads(line.strip())
                            self.received_messages.append(message)
                        except json.JSONDecodeError:
                            print(f" Invalid JSON received: {line}")

            except socket.timeout:
                continue
            except Exception as e:
                print(f" Message receiver error: {e}")
                break

    def send_message(self, message: Dict[str, Any]) -> bool:
        """Send JSON message to server"""
        try:
            json_str = json.dumps(message) + '\n'
            self.socket.send(json_str.encode('utf-8'))
            return True
        except Exception as e:
            print(f" Failed to send message: {e}")
            return False

    def wait_for_message(self, message_type: str, timeout: float = 5.0) -> Optional[Dict]:
        """Wait for specific message type from server"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            for i, msg in enumerate(self.received_messages):
                if msg.get('type') == message_type:
                    return self.received_messages.pop(i)
            time.sleep(0.1)

        return None

    def test_panel_connection(self, panel_id: str) -> bool:
        """Test if panel can connect and receive configuration"""
        print(f"\n=== Testing Panel Connection: {panel_id} ===")

        # Send heartbeat as if we're the panel
        heartbeat = {
            "type": "panel_heartbeat",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "data": {
                "client_id": panel_id,
                "ping": datetime.utcnow().isoformat() + "Z"
            }
        }

        if not self.send_message(heartbeat):
            self.test_results.append(f" {panel_id}: Failed to send heartbeat")
            return False

        print(f" Sent heartbeat for {panel_id}")

        # Wait for configuration response
        config_msg = self.wait_for_message("panel_config", 10.0)
        if config_msg:
            panel_config = config_msg.get('data', {})
            device_count = len(panel_config.get('devices', []))
            print(f" Received configuration with {device_count} devices")
            self.test_results.append(f" {panel_id}: Connection successful ({device_count} devices)")
            return True
        else:
            self.test_results.append(f" {panel_id}: No configuration received")
            return False

    def test_input_device(self, panel_id: str, device_id: str, test_values: List[float]) -> bool:
        """Test input device by sending various values"""
        print(f"\n--- Testing Input Device: {device_id} ---")

        success_count = 0
        for value in test_values:
            input_msg = {
                "type": "panel_input",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "data": {
                    "panel_id": panel_id,
                    "device_id": device_id,
                    "value": value,
                    "context": {
                        "raw_value": value,
                        "calibrated": True
                    }
                }
            }

            if self.send_message(input_msg):
                print(f"   Sent {device_id} = {value}")
                success_count += 1
                time.sleep(0.1)
            else:
                print(f"   Failed to send {device_id} = {value}")

        success_rate = (success_count / len(test_values)) * 100
        print(f"  Input test success rate: {success_rate:.1f}%")

        result = success_rate >= 90
        result_str = "" if result else ""
        self.test_results.append(f"{result_str} {panel_id}.{device_id}: Input test {success_rate:.1f}%")
        return result

    def test_output_device(self, panel_id: str, device_id: str, commands: List[Dict]) -> bool:
        """Test output device by sending commands"""
        print(f"\n--- Testing Output Device: {device_id} ---")

        success_count = 0
        for cmd in commands:
            output_msg = {
                "type": "panel_output",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "data": {
                    "panel_id": panel_id,
                    "device_id": device_id,
                    "command": cmd["command"],
                    "value": cmd["value"]
                }
            }

            if cmd.get("context"):
                output_msg["data"]["context"] = cmd["context"]

            if self.send_message(output_msg):
                print(f"   Sent {cmd['command']} = {cmd['value']}")
                success_count += 1
                time.sleep(0.5)  # Allow time for visual verification
            else:
                print(f"   Failed to send {cmd['command']} = {cmd['value']}")

        success_rate = (success_count / len(commands)) * 100
        print(f"  Output test success rate: {success_rate:.1f}%")

        result = success_rate >= 90
        result_str = "" if result else ""
        self.test_results.append(f"{result_str} {panel_id}.{device_id}: Output test {success_rate:.1f}%")
        return result

    def test_helm_panel(self) -> bool:
        """Comprehensive test of helm panel"""
        panel_id = "helm_main"

        if not self.test_panel_connection(panel_id):
            return False

        # Test input devices
        input_tests = [
            ("throttle", [0, 0.25, 0.5, 0.75, 1.0, 0]),
            ("rudder", [-1.0, -0.5, 0, 0.5, 1.0, 0]),
            ("pitch", [-1.0, 0, 1.0, 0]),
            ("roll", [-1.0, 0, 1.0, 0]),
            ("autopilot_btn", [0, 1, 0]),
            ("warp_dial", [0, 1, 2, 3, 4, 5, 0])
        ]

        for device_id, values in input_tests:
            self.test_input_device(panel_id, device_id, values)

        # Test output devices
        output_tests = [
            ("engine_led", [
                {"command": "set_brightness", "value": 0},
                {"command": "set_brightness", "value": 128},
                {"command": "set_brightness", "value": 255},
                {"command": "blink", "value": {"rate": 500, "duration": 3000}},
                {"command": "set_brightness", "value": 0}
            ]),
            ("nav_display", [
                {"command": "set_text", "value": "0000"},
                {"command": "set_text", "value": "1234"},
                {"command": "set_brightness", "value": 15},
                {"command": "set_text", "value": "HELM"}
            ])
        ]

        for device_id, commands in output_tests:
            self.test_output_device(panel_id, device_id, commands)

        return True

    def test_tactical_panel(self) -> bool:
        """Comprehensive test of tactical weapons panel"""
        panel_id = "tactical_weapons"

        if not self.test_panel_connection(panel_id):
            return False

        # Test input devices
        input_tests = [
            ("phaser_btn", [0, 1, 0]),
            ("torpedo_btn", [0, 1, 0]),
            ("target_lock", [0, 1, 0]),
            ("shield_power", [0, 0.5, 1.0, 0.75]),
            ("weapon_power", [0, 0.8, 1.0, 0.6])
        ]

        for device_id, values in input_tests:
            self.test_input_device(panel_id, device_id, values)

        # Test output devices
        output_tests = [
            ("alert_lights", [
                {"command": "set_all", "value": [255, 0, 0]},  # Red alert
                {"command": "set_all", "value": [255, 255, 0]},  # Yellow alert
                {"command": "set_all", "value": [0, 255, 0]},  # Green all clear
                {"command": "set_all", "value": [0, 0, 0]}  # Off
            ]),
            ("weapon_status", [
                {"command": "set_state", "value": True},
                {"command": "blink", "value": {"rate": 200, "duration": 2000}},
                {"command": "set_state", "value": False}
            ]),
            ("ammo_display", [
                {"command": "set_text", "value": "10"},
                {"command": "set_text", "value": "05"},
                {"command": "set_text", "value": "00"},
                {"command": "set_text", "value": "MAX"}
            ])
        ]

        for device_id, commands in output_tests:
            self.test_output_device(panel_id, device_id, commands)

        return True

    def test_communication_panel(self) -> bool:
        """Test communication panel devices"""
        panel_id = "comm_main"

        if not self.test_panel_connection(panel_id):
            return False

        # Test input devices
        input_tests = [
            ("freq_dial", [0, 10, 25, 50, 75, 100]),
            ("transmit_btn", [0, 1, 0]),
            ("emergency_btn", [0, 1, 0]),
            ("channel_sel", [0, 1, 2, 3, 4, 0])
        ]

        for device_id, values in input_tests:
            self.test_input_device(panel_id, device_id, values)

        # Test output devices
        output_tests = [
            ("signal_strength", [
                {"command": "set_level", "value": 0.0},
                {"command": "set_level", "value": 0.3},
                {"command": "set_level", "value": 0.7},
                {"command": "set_level", "value": 1.0}
            ]),
            ("freq_display", [
                {"command": "set_text", "value": "146.5"},
                {"command": "set_text", "value": "440.0"},
                {"command": "set_text", "value": "SCAN"}
            ])
        ]

        for device_id, commands in output_tests:
            self.test_output_device(panel_id, device_id, commands)

        return True

    def test_all_panels(self) -> bool:
        """Test all panel types"""
        print("\n" + "="*50)
        print("PANEL TESTER")
        print("="*50)

        panel_tests = [
            ("Helm Panel", self.test_helm_panel),
            ("Tactical Panel", self.test_tactical_panel),
            ("Communication Panel", self.test_communication_panel)
        ]

        success_count = 0
        for name, test_func in panel_tests:
            print(f"\n{'='*20} {name} {'='*20}")
            try:
                if test_func():
                    success_count += 1
                    print(f" {name} test completed")
                else:
                    print(f" {name} test failed")
            except Exception as e:
                print(f" {name} test error: {e}")

        return success_count == len(panel_tests)

    def run_stress_test(self, panel_id: str, duration: int = 60) -> bool:
        """Run stress test with rapid input changes"""
        print(f"\n=== Stress Test: {panel_id} ({duration}s) ===")

        if not self.test_panel_connection(panel_id):
            return False

        start_time = time.time()
        message_count = 0
        error_count = 0

        while time.time() - start_time < duration:
            # Send rapid input changes
            for i in range(5):
                input_msg = {
                    "type": "panel_input",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "data": {
                        "panel_id": panel_id,
                        "device_id": f"test_device_{i}",
                        "value": (time.time() % 1000) / 1000.0,
                        "context": {"raw_value": message_count}
                    }
                }

                if self.send_message(input_msg):
                    message_count += 1
                else:
                    error_count += 1

                time.sleep(0.02)  # 50Hz update rate

        error_rate = (error_count / max(1, message_count + error_count)) * 100
        print(f" Stress test completed:")
        print(f"  Messages sent: {message_count}")
        print(f"  Errors: {error_count}")
        print(f"  Error rate: {error_rate:.2f}%")

        success = error_rate < 5.0
        result_str = "" if success else ""
        self.test_results.append(f"{result_str} {panel_id}: Stress test {error_rate:.2f}% errors")
        return success

    def print_test_summary(self):
        """Print summary of all test results"""
        print("\n" + "="*50)
        print("TEST SUMMARY")
        print("="*50)

        passed = 0
        failed = 0

        for result in self.test_results:
            print(result)
            if result.startswith(""):
                passed += 1
            else:
                failed += 1

        total = passed + failed
        if total > 0:
            pass_rate = (passed / total) * 100
            print(f"\nOverall Results: {passed}/{total} tests passed ({pass_rate:.1f}%)")
        else:
            print("\nNo tests completed")

def main():
    parser = argparse.ArgumentParser(description="Celestial ESP32 Panel Tester")
    parser.add_argument("--host", default="127.0.0.1", help="Server host address")
    parser.add_argument("--port", type=int, default=8081, help="Server port")
    parser.add_argument("--panel", help="Test specific panel (helm_main, tactical_weapons, etc.)")
    parser.add_argument("--all", action="store_true", help="Test all panel types")
    parser.add_argument("--stress", type=int, help="Run stress test for N seconds")
    parser.add_argument("--input-test", nargs=2, metavar=("PANEL", "DEVICE"),
                       help="Test specific input device")
    parser.add_argument("--output-test", nargs=2, metavar=("PANEL", "DEVICE"),
                       help="Test specific output device")

    args = parser.parse_args()

    tester = PanelTester(args.host, args.port)

    try:
        if not tester.connect():
            return 1

        if args.all:
            tester.test_all_panels()
        elif args.panel:
            if args.stress:
                tester.run_stress_test(args.panel, args.stress)
            else:
                tester.test_panel_connection(args.panel)
        elif args.input_test:
            panel_id, device_id = args.input_test
            test_values = [0, 0.25, 0.5, 0.75, 1.0, 0]
            tester.test_input_device(panel_id, device_id, test_values)
        elif args.output_test:
            panel_id, device_id = args.output_test
            commands = [
                {"command": "set_brightness", "value": 0},
                {"command": "set_brightness", "value": 255},
                {"command": "set_state", "value": False}
            ]
            tester.test_output_device(panel_id, device_id, commands)
        else:
            print("No test specified. Use --help for options.")
            return 1

        tester.print_test_summary()

    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
    except Exception as e:
        print(f"\nTest failed with error: {e}")
        return 1
    finally:
        tester.disconnect()

    return 0

if __name__ == "__main__":
    sys.exit(main())
