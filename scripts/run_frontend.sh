#!/bin/bash

# Celestial Bridge Simulator - Frontend Development Script
# This script helps start the Godot frontend for development

set -e

# Configuration
GODOT_EXECUTABLE="godot"
PROJECT_PATH="$(dirname "$0")/../frontend"
LOG_FILE="frontend.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[CELESTIAL]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Godot is installed
check_godot() {
    print_status "Checking for Godot installation..."

    if command -v $GODOT_EXECUTABLE &> /dev/null; then
        GODOT_VERSION=$($GODOT_EXECUTABLE --version 2>/dev/null || echo "unknown")
        print_success "Found Godot: $GODOT_VERSION"
        return 0
    elif command -v godot4 &> /dev/null; then
        GODOT_EXECUTABLE="godot4"
        GODOT_VERSION=$($GODOT_EXECUTABLE --version 2>/dev/null || echo "unknown")
        print_success "Found Godot 4: $GODOT_VERSION"
        return 0
    else
        print_error "Godot not found in PATH"
        print_error "Please install Godot 4.4+ or add it to your PATH"
        return 1
    fi
}

# Function to check project structure
check_project() {
    print_status "Checking project structure..."

    if [ ! -f "$PROJECT_PATH/project.godot" ]; then
        print_error "project.godot not found at $PROJECT_PATH"
        print_error "Make sure you're running this script from the correct location"
        return 1
    fi

    if [ ! -d "$PROJECT_PATH/scripts" ]; then
        print_error "Scripts directory not found"
        return 1
    fi

    if [ ! -d "$PROJECT_PATH/scenes" ]; then
        print_error "Scenes directory not found"
        return 1
    fi

    print_success "Project structure verified"
    return 0
}

# Function to check backend connectivity
check_backend() {
    print_status "Checking backend connectivity..."

    if nc -z localhost 8080 2>/dev/null; then
        print_success "Backend server detected on localhost:8080"
    else
        print_warning "Backend server not detected on localhost:8080"
        print_warning "Make sure the backend is running before starting frontend"
    fi
}

# Function to run the frontend
run_frontend() {
    print_status "Starting Celestial Frontend..."

    cd "$PROJECT_PATH"

    # Create log directory if it doesn't exist
    mkdir -p logs

    # Run Godot with the project
    print_status "Launching Godot with project..."

    if [ "$1" = "--headless" ]; then
        print_status "Running in headless mode for testing..."
        $GODOT_EXECUTABLE --headless --path . > "logs/$LOG_FILE" 2>&1 &
        GODOT_PID=$!
        print_success "Frontend started in headless mode (PID: $GODOT_PID)"
    elif [ "$1" = "--editor" ]; then
        print_status "Opening in Godot Editor..."
        $GODOT_EXECUTABLE --editor --path . > "logs/$LOG_FILE" 2>&1 &
        GODOT_PID=$!
        print_success "Godot Editor opened (PID: $GODOT_PID)"
    else
        print_status "Running frontend in play mode..."
        $GODOT_EXECUTABLE --path . > "logs/$LOG_FILE" 2>&1 &
        GODOT_PID=$!
        print_success "Frontend started (PID: $GODOT_PID)"
    fi

    # Save PID for cleanup
    echo $GODOT_PID > "logs/frontend.pid"
}

# Function to stop the frontend
stop_frontend() {
    print_status "Stopping frontend..."

    if [ -f "$PROJECT_PATH/logs/frontend.pid" ]; then
        PID=$(cat "$PROJECT_PATH/logs/frontend.pid")
        if ps -p $PID > /dev/null 2>&1; then
            kill $PID
            print_success "Frontend stopped (PID: $PID)"
        else
            print_warning "Frontend process not found"
        fi
        rm -f "$PROJECT_PATH/logs/frontend.pid"
    else
        print_warning "No PID file found"
    fi
}

# Function to show usage
show_usage() {
    echo "Celestial Bridge Simulator - Frontend Development Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  run, start          Start the frontend in play mode (default)"
    echo "  editor              Open the project in Godot Editor"
    echo "  headless            Run in headless mode for testing"
    echo "  stop                Stop the running frontend"
    echo "  check               Check system requirements and project"
    echo "  logs                Show recent log output"
    echo "  clean               Clean temporary files and logs"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Start frontend"
    echo "  $0 editor           # Open in editor"
    echo "  $0 check            # Verify setup"
    echo "  $0 logs             # View logs"
}

# Function to show logs
show_logs() {
    if [ -f "$PROJECT_PATH/logs/$LOG_FILE" ]; then
        print_status "Recent frontend logs:"
        tail -n 50 "$PROJECT_PATH/logs/$LOG_FILE"
    else
        print_warning "No log file found"
    fi
}

# Function to clean temporary files
clean_temp() {
    print_status "Cleaning temporary files..."

    cd "$PROJECT_PATH"

    # Remove Godot temporary files
    rm -rf .godot/
    rm -rf .tmp/
    rm -f *.tmp

    # Clean logs older than 7 days
    if [ -d "logs" ]; then
        find logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
    fi

    print_success "Cleanup completed"
}

# Function to perform system check
system_check() {
    print_status "Performing system check..."

    # Check Godot
    if ! check_godot; then
        return 1
    fi

    # Check project
    if ! check_project; then
        return 1
    fi

    # Check backend
    check_backend

    # Check system resources
    print_status "Checking system resources..."

    # Check available memory (Linux/macOS)
    if command -v free &> /dev/null; then
        MEM_AVAILABLE=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
        print_status "Available memory: ${MEM_AVAILABLE}GB"
    elif command -v vm_stat &> /dev/null; then
        # macOS memory check
        print_status "Memory check available via Activity Monitor"
    fi

    # Check disk space
    DISK_AVAILABLE=$(df -h "$PROJECT_PATH" | awk 'NR==2 {print $4}')
    print_status "Available disk space: $DISK_AVAILABLE"

    print_success "System check completed"
}

# Main script logic
case "${1:-run}" in
    "run"|"start"|"")
        system_check && run_frontend
        ;;
    "editor")
        system_check && run_frontend --editor
        ;;
    "headless")
        system_check && run_frontend --headless
        ;;
    "stop")
        stop_frontend
        ;;
    "check")
        system_check
        ;;
    "logs")
        show_logs
        ;;
    "clean")
        clean_temp
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
