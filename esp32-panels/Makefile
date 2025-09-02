# Celestial ESP32 Panel System Makefile

.PHONY: help all clean build upload monitor test install-deps list-panels flash-all

# Default target
help:
	@echo "Celestial ESP32 Panel System"
	@echo "============================"
	@echo ""
	@echo "Available targets:"
	@echo "  all                    - Build all panel types"
	@echo "  clean                  - Clean build artifacts"
	@echo "  build PANEL=<name>     - Build specific panel"
	@echo "  upload PANEL=<name>    - Build and upload panel"
	@echo "  monitor PANEL=<name>   - Open serial monitor"
	@echo "  flash PANEL=<name>     - Build, upload, and monitor"
	@echo "  test                   - Run panel tests"
	@echo "  install-deps           - Install dependencies"
	@echo "  list-panels            - List available panel types"
	@echo "  flash-all              - Build and flash all panels"
	@echo ""
	@echo "Panel types:"
	@echo "  helm_main, tactical_weapons, comm_main,"
	@echo "  engineering_power, captain_console"
	@echo ""
	@echo "Examples:"
	@echo "  make build PANEL=helm_main"
	@echo "  make flash PANEL=tactical_weapons"
	@echo "  make test"

# Variables
PANEL ?= helm_main
BUILD_SCRIPT = ./build.sh
TEST_SCRIPT = ./test_panel.py
PANELS = helm_main tactical_weapons comm_main engineering_power captain_console

# Check if panel is valid
check-panel:
	@if ! echo "$(PANELS)" | grep -q "$(PANEL)"; then \
		echo "Error: Invalid panel '$(PANEL)'"; \
		echo "Valid panels: $(PANELS)"; \
		exit 1; \
	fi

# Build all panels
all:
	$(BUILD_SCRIPT) --all

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@for panel in $(PANELS); do \
		pio run -e $$panel -t clean 2>/dev/null || true; \
	done
	@echo "Clean complete"

# Build specific panel
build: check-panel
	$(BUILD_SCRIPT) $(PANEL)

# Build and upload
upload: check-panel
	$(BUILD_SCRIPT) -u $(PANEL)

# Open serial monitor
monitor: check-panel
	@echo "Opening serial monitor for $(PANEL)..."
	@echo "Press Ctrl+C to exit"
	pio device monitor

# Build, upload, and monitor
flash: check-panel
	$(BUILD_SCRIPT) -cum $(PANEL)

# Run tests
test:
	@if [ -f $(TEST_SCRIPT) ]; then \
		python3 $(TEST_SCRIPT) --all; \
	else \
		echo "Test script not found"; \
	fi

# Test specific panel
test-panel: check-panel
	@if [ -f $(TEST_SCRIPT) ]; then \
		python3 $(TEST_SCRIPT) --panel $(PANEL); \
	else \
		echo "Test script not found"; \
	fi

# Install dependencies
install-deps:
	@echo "Installing PlatformIO dependencies..."
	@if ! command -v pio >/dev/null 2>&1; then \
		echo "Installing PlatformIO..."; \
		pip install platformio; \
	fi
	@echo "Installing Python dependencies..."
	@pip install -r requirements.txt 2>/dev/null || echo "No requirements.txt found"
	@echo "Dependencies installed"

# List available panels
list-panels:
	@echo "Available panel types:"
	@for panel in $(PANELS); do \
		echo "  $$panel"; \
	done

# Build and flash all panels (requires manual intervention)
flash-all:
	@echo "Building and flashing all panels..."
	@echo "You will need to connect each panel manually when prompted."
	@for panel in $(PANELS); do \
		echo ""; \
		echo "========================================"; \
		echo "Preparing to flash $$panel"; \
		echo "========================================"; \
		read -p "Connect $$panel and press Enter to continue..."; \
		$(BUILD_SCRIPT) -u $$panel || echo "Failed to flash $$panel"; \
	done

# Size report for all panels
size:
	@echo "Firmware size report:"
	@for panel in $(PANELS); do \
		echo ""; \
		echo "=== $$panel ==="; \
		pio run -e $$panel -t size 2>/dev/null || echo "Not built"; \
	done

# Format code
format:
	@echo "Formatting code..."
	@find src -name "*.cpp" -o -name "*.h" | xargs clang-format -i 2>/dev/null || echo "clang-format not available"

# Lint code
lint:
	@echo "Linting code..."
	@pio check 2>/dev/null || echo "PlatformIO check not available"

# Create release package
package:
	@echo "Creating release package..."
	@mkdir -p release
	@for panel in $(PANELS); do \
		pio run -e $$panel; \
		cp .pio/build/$$panel/firmware.bin release/$$panel.bin 2>/dev/null || true; \
	done
	@echo "Release packages created in release/"

# Quick setup for new development environment
setup: install-deps
	@echo "Setting up development environment..."
	@chmod +x $(BUILD_SCRIPT)
	@chmod +x $(TEST_SCRIPT)
	@echo "Environment setup complete"

# Documentation
docs:
	@echo "Opening documentation..."
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open ../docs/panel-hardware.md; \
	elif command -v open >/dev/null 2>&1; then \
		open ../docs/panel-hardware.md; \
	else \
		echo "Documentation available in ../docs/"; \
	fi
