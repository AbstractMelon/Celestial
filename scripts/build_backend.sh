#!/bin/bash

# Celestial Bridge Simulator - Build Script
# This script builds the Go backend for development and production

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
BUILD_TYPE="development"
VERBOSE=false
CLEAN=false
OUTPUT_DIR="$BACKEND_DIR/bin"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -t, --type TYPE      Build type: development (default) or production"
    echo "  -o, --output DIR     Output directory (default: ./bin)"
    echo "  -c, --clean          Clean before building"
    echo "  -v, --verbose        Verbose output"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Development build"
    echo "  $0 -t production            # Production build"
    echo "  $0 -c -v                    # Clean verbose development build"
    echo "  $0 -t production -o /opt/celestial/bin  # Production build to custom directory"
}

log() {
    echo -e "${BLUE}[BUILD]${NC} $1"
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
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
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

# Validate build type
if [[ "$BUILD_TYPE" != "development" && "$BUILD_TYPE" != "production" ]]; then
    log_error "Invalid build type: $BUILD_TYPE (must be 'development' or 'production')"
    exit 1
fi

log "Starting Celestial Backend Build"
log "================================"
log "Build type: $BUILD_TYPE"
log "Output directory: $OUTPUT_DIR"
log "Backend directory: $BACKEND_DIR"

# Change to backend directory
cd "$BACKEND_DIR"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    log_error "Go is not installed or not in PATH"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
log "Go version: $GO_VERSION"

# Clean if requested
if [[ "$CLEAN" == true ]]; then
    log "Cleaning previous builds..."
    rm -rf "$OUTPUT_DIR"
    go clean -cache
    go clean -modcache
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Download dependencies
log "Downloading dependencies..."
if [[ "$VERBOSE" == true ]]; then
    go mod download -x
else
    go mod download
fi

# Verify dependencies
log "Verifying dependencies..."
go mod verify

# Tidy up go.mod
go mod tidy

# Set build flags based on build type
BUILD_FLAGS=""
LDFLAGS=""

if [[ "$BUILD_TYPE" == "production" ]]; then
    log "Configuring production build..."
    # Production optimizations
    BUILD_FLAGS="-trimpath"
    LDFLAGS="-s -w"

    # Add build info
    VERSION=${VERSION:-"unknown"}
    COMMIT=${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}
    BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    LDFLAGS="$LDFLAGS -X main.version=$VERSION -X main.commit=$COMMIT -X main.buildTime=$BUILD_TIME"
else
    log "Configuring development build..."
    # Development build with race detection
    BUILD_FLAGS="-race"
fi

# Build the application
log "Building application..."
BUILD_CMD="go build $BUILD_FLAGS"

if [[ "$LDFLAGS" != "" ]]; then
    BUILD_CMD="$BUILD_CMD -ldflags=\"$LDFLAGS\""
fi

BUILD_CMD="$BUILD_CMD -o \"$OUTPUT_DIR/celestial-backend\" ."

if [[ "$VERBOSE" == true ]]; then
    log "Build command: $BUILD_CMD"
fi

eval $BUILD_CMD

if [[ $? -eq 0 ]]; then
    log_success "Build completed successfully!"
else
    log_error "Build failed!"
    exit 1
fi

# Check if binary was created
BINARY_PATH="$OUTPUT_DIR/celestial-backend"
if [[ ! -f "$BINARY_PATH" ]]; then
    log_error "Binary not found at $BINARY_PATH"
    exit 1
fi

# Make binary executable
chmod +x "$BINARY_PATH"

# Show binary info
BINARY_SIZE=$(ls -lh "$BINARY_PATH" | awk '{print $5}')
log "Binary size: $BINARY_SIZE"
log "Binary location: $BINARY_PATH"

# Create configuration directory and default config if it doesn't exist
CONFIG_DIR="$BACKEND_DIR/config"
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    log "Creating default configuration..."
    "$BINARY_PATH" -config="$CONFIG_DIR/config.json" &
    sleep 2
    pkill -f "celestial-backend" || true

    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        log_success "Default configuration created at $CONFIG_DIR/config.json"
    else
        log_warning "Could not create default configuration"
    fi
fi

# Create missions directory
MISSIONS_DIR="$BACKEND_DIR/missions"
mkdir -p "$MISSIONS_DIR"

# Copy tutorial mission if it doesn't exist
if [[ ! -f "$MISSIONS_DIR/tutorial.lua" && -f "$BACKEND_DIR/missions/tutorial.lua" ]]; then
    log "Tutorial mission already exists"
else
    log_success "Tutorial mission available at $MISSIONS_DIR/tutorial.lua"
fi

# Create logs directory
mkdir -p "$BACKEND_DIR/logs"

# Create static files directory
mkdir -p "$BACKEND_DIR/static"

# Run tests if in development mode
if [[ "$BUILD_TYPE" == "development" ]]; then
    log "Running tests..."
    if go test ./... -v; then
        log_success "All tests passed!"
    else
        log_warning "Some tests failed (build still successful)"
    fi
fi

# Print completion message
echo ""
log_success "Build process completed!"
echo ""
echo "To run the server:"
echo "  $BINARY_PATH"
echo ""
echo "To run with custom config:"
echo "  $BINARY_PATH -config=path/to/config.json"
echo ""
echo "To run with a mission:"
echo "  $BINARY_PATH -mission=missions/tutorial.lua"
echo ""
echo "To run in debug mode:"
echo "  $BINARY_PATH -debug"
echo ""

# Show next steps
if [[ "$BUILD_TYPE" == "development" ]]; then
    echo "Development build complete. The binary includes race detection."
    echo "For production deployment, run: $0 -t production"
else
    echo "Production build complete. Binary is optimized and stripped."
    echo "Deploy the contents of $OUTPUT_DIR to your production server."
fi

echo ""
log "Happy flying!"
