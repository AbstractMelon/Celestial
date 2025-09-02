#!/bin/bash

# Celestial ESP32 Panel Build Script
# Builds firmware for all panel types or specific panel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Panel types
PANELS=("helm_main" "tactical_weapons" "comm_main" "engineering_power" "captain_console")

print_usage() {
    echo "Usage: $0 [OPTIONS] [PANEL_TYPE]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build artifacts before building"
    echo "  -u, --upload   Upload firmware after building"
    echo "  -m, --monitor  Open serial monitor after upload"
    echo "  -a, --all      Build all panel types"
    echo "  -l, --list     List available panel types"
    echo ""
    echo "Panel Types:"
    for panel in "${PANELS[@]}"; do
        echo "  $panel"
    done
    echo ""
    echo "Examples:"
    echo "  $0 helm_main                    # Build helm panel firmware"
    echo "  $0 -u helm_main                # Build and upload helm panel"
    echo "  $0 -cum tactical_weapons       # Clean, build, upload, and monitor tactical panel"
    echo "  $0 -a                          # Build all panel types"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_platformio() {
    if ! command -v pio &> /dev/null; then
        log_error "PlatformIO CLI not found. Please install PlatformIO first."
        echo "Installation: pip install platformio"
        exit 1
    fi
}

check_panel_type() {
    local panel=$1
    for valid_panel in "${PANELS[@]}"; do
        if [[ "$panel" == "$valid_panel" ]]; then
            return 0
        fi
    done
    return 1
}

build_panel() {
    local panel=$1
    local clean=$2
    local upload=$3
    local monitor=$4

    log_info "Building firmware for panel: $panel"

    if [[ "$clean" == "true" ]]; then
        log_info "Cleaning build artifacts..."
        pio run -e "$panel" -t clean
    fi

    log_info "Compiling firmware..."
    if pio run -e "$panel"; then
        log_success "Build completed for $panel"

        # Show firmware size
        log_info "Firmware size information:"
        pio run -e "$panel" -t size

        if [[ "$upload" == "true" ]]; then
            log_info "Uploading firmware to device..."
            if pio run -e "$panel" -t upload; then
                log_success "Upload completed for $panel"

                if [[ "$monitor" == "true" ]]; then
                    log_info "Opening serial monitor..."
                    log_info "Press Ctrl+C to exit monitor"
                    sleep 2
                    pio device monitor
                fi
            else
                log_error "Upload failed for $panel"
                return 1
            fi
        fi
    else
        log_error "Build failed for $panel"
        return 1
    fi
}

build_all_panels() {
    local clean=$1
    local success_count=0
    local total_count=${#PANELS[@]}

    log_info "Building firmware for all panel types..."

    for panel in "${PANELS[@]}"; do
        echo ""
        log_info "========================================"
        log_info "Building $panel ($((success_count + 1))/$total_count)"
        log_info "========================================"

        if build_panel "$panel" "$clean" "false" "false"; then
            ((success_count++))
        else
            log_warning "Build failed for $panel, continuing with next panel..."
        fi
    done

    echo ""
    log_info "========================================"
    log_info "Build Summary"
    log_info "========================================"
    log_info "Successful builds: $success_count/$total_count"

    if [[ $success_count -eq $total_count ]]; then
        log_success "All panel builds completed successfully!"
        return 0
    else
        log_warning "Some panel builds failed. Check output above for details."
        return 1
    fi
}

list_panels() {
    log_info "Available panel types:"
    for panel in "${PANELS[@]}"; do
        echo "  - $panel"
    done
}

# Parse command line arguments
CLEAN=false
UPLOAD=false
MONITOR=false
BUILD_ALL=false
PANEL_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -u|--upload)
            UPLOAD=true
            shift
            ;;
        -m|--monitor)
            MONITOR=true
            shift
            ;;
        -a|--all)
            BUILD_ALL=true
            shift
            ;;
        -l|--list)
            list_panels
            exit 0
            ;;
        -*)
            # Handle combined flags like -cum
            if [[ $1 =~ ^-[cuma]+$ ]]; then
                [[ $1 =~ c ]] && CLEAN=true
                [[ $1 =~ u ]] && UPLOAD=true
                [[ $1 =~ m ]] && MONITOR=true
                [[ $1 =~ a ]] && BUILD_ALL=true
                shift
            else
                log_error "Unknown option: $1"
                print_usage
                exit 1
            fi
            ;;
        *)
            if [[ -z "$PANEL_TYPE" ]]; then
                PANEL_TYPE=$1
            else
                log_error "Multiple panel types specified: $PANEL_TYPE and $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ "$BUILD_ALL" == "true" && -n "$PANEL_TYPE" ]]; then
    log_error "Cannot specify both --all and a specific panel type"
    exit 1
fi

if [[ "$BUILD_ALL" == "false" && -z "$PANEL_TYPE" ]]; then
    log_error "Must specify either a panel type or --all"
    print_usage
    exit 1
fi

if [[ -n "$PANEL_TYPE" ]] && ! check_panel_type "$PANEL_TYPE"; then
    log_error "Invalid panel type: $PANEL_TYPE"
    log_info "Use --list to see available panel types"
    exit 1
fi

# Validate monitor option
if [[ "$MONITOR" == "true" && "$UPLOAD" == "false" ]]; then
    log_error "Monitor option requires upload option (-u)"
    exit 1
fi

if [[ "$MONITOR" == "true" && "$BUILD_ALL" == "true" ]]; then
    log_error "Monitor option cannot be used with --all"
    exit 1
fi

# Main execution
log_info "Celestial ESP32 Panel Build System"
log_info "=================================="

check_platformio

if [[ "$BUILD_ALL" == "true" ]]; then
    build_all_panels "$CLEAN"
else
    build_panel "$PANEL_TYPE" "$CLEAN" "$UPLOAD" "$MONITOR"
fi

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    log_success "Build process completed successfully!"
else
    log_error "Build process failed!"
fi

exit $exit_code
