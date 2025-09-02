#!/bin/bash

# Celestial Bridge Simulator - Development Run Script
# This script runs the Go backend with development settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/../backend"
PROJECT_ROOT="$(dirname "$BACKEND_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONFIG_FILE="$BACKEND_DIR/config/config.json"
MISSION_FILE=""
DEBUG=false
BUILD=true
BINARY_PATH="$BACKEND_DIR/bin/celestial-backend"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -c, --config FILE    Configuration file (default: ./config/config.json)"
    echo "  -m, --mission FILE   Mission file to load on startup"
    echo "  -d, --debug          Enable debug mode"
    echo "  -n, --no-build       Don't build before running"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run with default config"
    echo "  $0 -d                                 # Run in debug mode"
    echo "  $0 -m missions/tutorial.lua          # Run with tutorial mission"
    echo "  $0 -c custom-config.json -d          # Run with custom config in debug mode"
    echo "  $0 -n                                 # Run without building (use existing binary)"
}

log() {
    echo -e "${BLUE}[RUN]${NC} $1"
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -m|--mission)
            MISSION_FILE="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -n|--no-build)
            BUILD=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

log "Starting Celestial Backend Development Server"
log "============================================="
log "Backend directory: $BACKEND_DIR"
log "Config file: $CONFIG_FILE"

if [[ "$MISSION_FILE" != "" ]]; then
    log "Mission file: $MISSION_FILE"
fi

log "Debug mode: $DEBUG"

# Change to backend directory
cd "$BACKEND_DIR"

# Build if requested
if [[ "$BUILD" == true ]]; then
    log "Building application..."
    if ! bash "$SCRIPT_DIR/build_backend.sh" -t development; then
        log_error "Build failed!"
        exit 1
    fi
    log_success "Build completed"
fi

# Check if binary exists
if [[ ! -f "$BINARY_PATH" ]]; then
    log_error "Binary not found at $BINARY_PATH"
    log "Run with build enabled or run the build script first"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warning "Config file not found at $CONFIG_FILE"
    log "Creating default configuration..."

    # Create config directory if it doesn't exist
    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    mkdir -p "$CONFIG_DIR"

    # Run binary briefly to generate default config
    timeout 3s "$BINARY_PATH" -config="$CONFIG_FILE" || true

    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Default configuration created"
    else
        log_error "Could not create default configuration"
        exit 1
    fi
fi

# Check if mission file exists (if specified)
if [[ "$MISSION_FILE" != "" && ! -f "$MISSION_FILE" ]]; then
    log_error "Mission file not found: $MISSION_FILE"
    exit 1
fi

# Create necessary directories
log "Creating necessary directories..."
mkdir -p "$BACKEND_DIR/logs"
mkdir -p "$BACKEND_DIR/static"
mkdir -p "$BACKEND_DIR/missions"

# Prepare run command
RUN_CMD="$BINARY_PATH -config=\"$CONFIG_FILE\""

if [[ "$MISSION_FILE" != "" ]]; then
    RUN_CMD="$RUN_CMD -mission=\"$MISSION_FILE\""
fi

if [[ "$DEBUG" == true ]]; then
    RUN_CMD="$RUN_CMD -debug"
fi

# Set up signal handling for graceful shutdown
cleanup() {
    log ""
    log "Received shutdown signal, stopping server..."
    if [[ -n $SERVER_PID ]]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    log_success "Server stopped gracefully"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Show startup information
echo ""
log_success "Starting development server..."
echo ""
echo "Server will be available at:"
echo "  WebSocket: ws://localhost:8080/ws"
echo "  HTTP API:  http://localhost:8080/api"
echo "  TCP Panel: localhost:8081"
echo "  Status:    http://localhost:8080/status"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run the server
log "Executing: $RUN_CMD"
echo ""

eval $RUN_CMD &
SERVER_PID=$!

# Wait for the server process
wait $SERVER_PID

# If we get here, the server exited on its own
log_warning "Server process exited"
