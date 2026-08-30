#!/bin/sh

set -e

NC='\033[0m'

log_error() {
	RED='\033[0;31m'
	echo "${RED}$1${NC}"
}

log_success() {
	GREEN='\033[0;32m'
	echo "${GREEN}$1${NC}"
}

log_warning() {
	YELLOW='\033[1;33m'
	echo "${YELLOW}$1${NC}"
}

log_info() {
	BLUE='\033[0;34m'
	echo "${BLUE}$1${NC}"
}

# Check if podman is installed
if ! command -v podman >/dev/null 2>&1; then
	log_error "Error: podman is not installed. Please install podman first."
	exit 1
fi

# Non-interactive mode.
FULL_UPGRADE=${FULL_UPGRADE:-"false"}
UPGRADE=${UPGRADE:-"false"}
NONINTERACTIVE=${NONINTERACTIVE:-"false"}

# Function to safely copy config file with backup
copy() {
	local src="$1"
	local dest="$2"

	# Check if config already exists
	if [ -f "$dest" ]; then
		log_warning "Warning: Existing ${dest} will be backed up"
		cp "$dest" "${dest}.bak"
	fi

	cp -f "$src" "$dest"
}

for arg in "$@"; do
	case $arg in
	--upgrade)
		UPGRADE="true"
		shift
		;;
	--full-upgrade)
		UPGRADE="true"
		FULL_UPGRADE="true"
		shift
		;;
	--noninteractive)
		NONINTERACTIVE="true"
		shift
		;;
	esac
done

log_info "Pulling image..."

if ! podman pull ghcr.io/hanyu-dev/oci-image-cloudflared:latest; then
	log_error "Error: Failed to pull image."
	exit 1
fi

if [ "$UPGRADE" = "true" ]; then
	if [ "$FULL_UPGRADE" = "true" ]; then
		log_info "Updating cloudflared service..."
		copy ./assets/deploy/cloudflared.container ~/.config/containers/systemd/cloudflared.container
		systemctl --user daemon-reload
	fi

	log_info "Restarting cloudflared service..."
	systemctl --user restart cloudflared
else
	mkdir -p ~/.config/containers/systemd
	copy ./assets/deploy/cloudflared.container ~/.config/containers/systemd/cloudflared.container

	# Edit if necessary (skip if --noninteractive is passed)
	if [ "$NONINTERACTIVE" != "true" ]; then
		log_info "Opening editor for configuration. Press Ctrl+X to exit nano."
		${EDITOR:-nano} ~/.config/containers/systemd/cloudflared.container
	fi

	# Check if linger is already enabled
	if ! loginctl show-user $USER --property=Linger | grep -q "Linger=yes"; then
		if [ "$NONINTERACTIVE" = "true" ]; then
			log_warning "Warning: Linger not enabled for user. Please run manually: sudo loginctl enable-linger $USER"
		else
			log_info "Enabling linger for user (requires sudo)..."
			sudo loginctl enable-linger $USER
		fi
	fi

	log_info "Starting cloudflared service..."

	systemctl --user daemon-reload
	systemctl --user start cloudflared

	log_success "Done! Check service status with: systemctl --user status cloudflared"
fi
