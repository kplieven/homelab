#!/bin/bash

# Update all Docker services in homelab setup
# Usage: ./update-containers.sh [options]
# Options:
#   --dry-run    Show what would be updated without actually doing it
#   --no-prune   Skip pruning unused images after update
#   --help       Show this help message

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script's directory and services directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SERVICES_DIR="$SCRIPT_DIR/../services"

# Default options
DRY_RUN=false
NO_PRUNE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-prune)
            NO_PRUNE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run    Show what would be updated without actually doing it"
            echo "  --no-prune   Skip pruning unused images after update"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Function to run command or show what would be run
run_command() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would run: $1"
    else
        eval "$1"
    fi
}

# Check if services directory exists
if [ ! -d "$SERVICES_DIR" ]; then
    print_error "Services directory not found at $SERVICES_DIR"
    exit 1
fi

print_status "Starting Docker services update..."
print_status "Services directory: $SERVICES_DIR"

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No actual changes will be made"
fi

# Counter for statistics
TOTAL_SERVICES=0
UPDATED_SERVICES=0
FAILED_SERVICES=0

# Find all docker-compose.yml files and update them
while IFS= read -r -d '' compose_file; do
    service_dir=$(dirname "$compose_file")
    service_name=$(basename "$service_dir")
    
    print_status "Processing service: $service_name"
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    # Change to service directory
    cd "$service_dir"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "  Would pull latest images for $service_name"
        print_status "  Would restart $service_name with new images"
    else
        # Pull latest images
        print_status "  Pulling latest images for $service_name..."
        if docker-compose pull; then
            print_status "  Restarting $service_name with new images..."
            if docker-compose up -d; then
                print_success "  Successfully updated $service_name"
                UPDATED_SERVICES=$((UPDATED_SERVICES + 1))
            else
                print_error "  Failed to restart $service_name"
                FAILED_SERVICES=$((FAILED_SERVICES + 1))
            fi
        else
            print_error "  Failed to pull images for $service_name"
            FAILED_SERVICES=$((FAILED_SERVICES + 1))
        fi
    fi
    
    echo ""  # Empty line for readability
    
done < <(find "$SERVICES_DIR" -name "docker-compose.yml" -print0)

# Return to script directory
cd "$SCRIPT_DIR"

# Clean up unused images (unless --no-prune is specified)
if [ "$NO_PRUNE" = false ]; then
    print_status "Cleaning up unused Docker images..."
    run_command "docker image prune -f"
    print_success "Cleanup completed"
else
    print_warning "Skipping image cleanup (--no-prune specified)"
fi

# Print summary
echo ""
print_status "========== UPDATE SUMMARY =========="
print_status "Total services found: $TOTAL_SERVICES"
if [ "$DRY_RUN" = false ]; then
    print_success "Successfully updated: $UPDATED_SERVICES"
    if [ $FAILED_SERVICES -gt 0 ]; then
        print_error "Failed to update: $FAILED_SERVICES"
    fi
else
    print_warning "Dry run completed - no actual changes made"
fi

# Exit with error code if any services failed to update
if [ $FAILED_SERVICES -gt 0 ] && [ "$DRY_RUN" = false ]; then
    exit 1
fi

print_success "Update process completed!"
