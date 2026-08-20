#!/bin/bash

# Update all Docker services in homelab setup
# Usage: ./update-and-run-containers.sh [options]
# Options:
#   --dry-run         Show what would be updated without actually doing it
#   --no-prune        Skip pruning unused images after update
#   --stop-disabled   Bring down stacks that are disabled but still running
#   --list            List services and their enabled/disabled state, then exit
#   --help            Show this help message
#
# Disabling a service:
#   Create a `.disabled` file in the service directory. The service is then
#   skipped by this script (not pulled, not started). Any text inside the file
#   is shown as the reason.
#
#     touch services/immich/.disabled
#     echo "paused until new disk arrives" > services/immich/.disabled
#
#   Re-enable by deleting the file:  rm services/immich/.disabled

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

# Name of the marker file that disables a service
DISABLED_MARKER=".disabled"

# Default options
DRY_RUN=false
NO_PRUNE=false
STOP_DISABLED=false
LIST_ONLY=false

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
        --stop-disabled)
            STOP_DISABLED=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run         Show what would be updated without actually doing it"
            echo "  --no-prune        Skip pruning unused images after update"
            echo "  --stop-disabled   Bring down stacks that are disabled but still running"
            echo "  --list            List services and their enabled/disabled state, then exit"
            echo "  --help            Show this help message"
            echo ""
            echo "Disabling a service:"
            echo "  touch services/SERVICE_NAME/$DISABLED_MARKER"
            echo "  echo \"reason\" > services/SERVICE_NAME/$DISABLED_MARKER   # optional reason"
            echo "  rm services/SERVICE_NAME/$DISABLED_MARKER                # re-enable"
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

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Function to run command or show what would be run
run_command() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would run: $1"
    else
        eval "$1"
    fi
}

# Walk up from a service directory to SERVICES_DIR looking for a marker file.
# Echoes the path of the marker that disables this service, or nothing.
find_disabled_marker() {
    local dir
    dir="$(readlink -f "$1")"
    local root
    root="$(readlink -f "$SERVICES_DIR")"

    while [ "${#dir}" -ge "${#root}" ]; do
        if [ -e "$dir/$DISABLED_MARKER" ]; then
            echo "$dir/$DISABLED_MARKER"
            return 0
        fi
        [ "$dir" = "$root" ] && break
        dir="$(dirname "$dir")"
    done
    return 1
}

# Read the optional reason stored inside a marker file
disabled_reason() {
    local reason
    reason=$(tr '\n' ' ' < "$1" 2>/dev/null | sed 's/[[:space:]]*$//')
    echo "$reason"
}

# Check if services directory exists
if [ ! -d "$SERVICES_DIR" ]; then
    print_error "Services directory not found at $SERVICES_DIR"
    exit 1
fi

# --list: report state of every service and exit
if [ "$LIST_ONLY" = true ]; then
    print_status "Services in $SERVICES_DIR"
    echo ""
    while IFS= read -r -d '' compose_file; do
        service_dir=$(dirname "$compose_file")
        service_name=$(basename "$service_dir")
        if marker=$(find_disabled_marker "$service_dir"); then
            reason=$(disabled_reason "$marker")
            if [ -n "$reason" ]; then
                echo -e "  ${YELLOW}disabled${NC}  $service_name  ($reason)"
            else
                echo -e "  ${YELLOW}disabled${NC}  $service_name"
            fi
        else
            echo -e "  ${GREEN}enabled ${NC}  $service_name"
        fi
    done < <(find "$SERVICES_DIR" -maxdepth 3 -name "docker-compose.yml" -print0 2>/dev/null | sort -z)
    echo ""
    exit 0
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
SKIPPED_SERVICES=0
FAILED_LIST=()

# Find all docker-compose.yml files and update them
while IFS= read -r -d '' compose_file; do
    service_dir=$(dirname "$compose_file")
    service_name=$(basename "$service_dir")

    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))

    # Change to service directory
    cd "$service_dir"

    # Skip services that are explicitly disabled
    if marker=$(find_disabled_marker "$service_dir"); then
        reason=$(disabled_reason "$marker")
        if [ -n "$reason" ]; then
            print_skip "$service_name is disabled ($reason)"
        else
            print_skip "$service_name is disabled"
        fi
        SKIPPED_SERVICES=$((SKIPPED_SERVICES + 1))

        # Warn (or act) if the stack is still running despite being disabled
        running=$(docker-compose ps --services --filter "status=running" 2>/dev/null || true)
        if [ -n "$running" ]; then
            if [ "$STOP_DISABLED" = true ]; then
                if [ "$DRY_RUN" = true ]; then
                    print_status "  Would run: docker-compose down (in $service_dir)"
                else
                    print_status "  Bringing down disabled stack $service_name..."
                    if docker-compose down; then
                        print_success "  Stopped $service_name"
                    else
                        print_error "  Failed to stop $service_name"
                        FAILED_SERVICES=$((FAILED_SERVICES + 1))
                        FAILED_LIST+=("$service_name (down)")
                    fi
                fi
            else
                print_warning "  $service_name is disabled but still running (use --stop-disabled to bring it down)"
            fi
        fi

        echo ""
        continue
    fi

    print_status "Processing service: $service_name"

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
                FAILED_LIST+=("$service_name (up)")
            fi
        else
            print_error "  Failed to pull images for $service_name"
            FAILED_SERVICES=$((FAILED_SERVICES + 1))
            FAILED_LIST+=("$service_name (pull)")
        fi
    fi

    echo ""  # Empty line for readability

done < <(find "$SERVICES_DIR" -maxdepth 3 -name "docker-compose.yml" -print0 2>/dev/null | sort -z)

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
if [ $SKIPPED_SERVICES -gt 0 ]; then
    print_warning "Skipped (disabled): $SKIPPED_SERVICES"
fi
if [ "$DRY_RUN" = false ]; then
    print_success "Successfully updated: $UPDATED_SERVICES"
    if [ $FAILED_SERVICES -gt 0 ]; then
        print_error "Failed to update: $FAILED_SERVICES"
        for failed in "${FAILED_LIST[@]}"; do
            print_error "  - $failed"
        done
    fi
else
    print_warning "Dry run completed - no actual changes made"
fi

# Exit with error code if any services failed to update
if [ $FAILED_SERVICES -gt 0 ] && [ "$DRY_RUN" = false ]; then
    exit 1
fi

print_success "Update process completed!"
