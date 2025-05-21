#!/usr/bin/env bash

# Check if bash is installed
if ! command -v bash &> /dev/null; then
    echo "Error: bash is not installed. Please install bash before running this script."
    echo "You can install bash using your system's package manager:"
    echo "  - For Debian/Ubuntu: sudo apt-get install bash"
    echo "  - For Fedora/RHEL: sudo dnf install bash"
    echo "  - For Arch Linux: sudo pacman -S bash"
    exit 1
fi

# Exit immediately if a command exits with a non-zero status.
set -e

# --- USER CONFIGURATION: PLEASE EDIT THESE VARIABLES ---
# Your GitHub repository URL for your Nix Flake configuration
# Example: GITHUB_REPO_URL="https://github.com/yourusername/my-nix-dots.git"
GITHUB_REPO_URL="https://github.com/JamesDevore/nix-config"

# The local directory where your Nix configuration will be cloned.
# This script will create this directory if it doesn't exist.
# Example: FLAKE_REPO_ROOT="$HOME/my-nix-setup"
FLAKE_REPO_ROOT="$HOME/nix-config" # Changed from ~/nix to avoid potential conflicts if ~/nix is special

# The name of the output in your flake.nix for Home Manager.
# This script attempts to construct it dynamically assuming a pattern like "username-architecture-linux".
# If your flake output name is static (e.g., "myDefaultHomeEnv"), set it directly:
# FLAKE_OUTPUT_NAME="myDefaultHomeEnv"
#
# Otherwise, if your flake output uses a prefix + architecture (e.g., "dev-x86_64-linux"):
FLAKE_OUTPUT_USERNAME="dev" # Or your actual username if used in the flake output
# FLAKE_OUTPUT_NAME will be constructed below using this and system architecture.
# --- END OF USER CONFIGURATION ---

# Function to print messages
log() {
  echo "--------------------------------------------------"
  echo "$1"
  echo "--------------------------------------------------"
}

# Check if script is run as root, exit if so, as some steps need user context
if [ "$(id -u)" -eq 0 ]; then
  log "ERROR: This script should not be run as root. It will use 'sudo' where necessary."
  exit 1
fi

# Detect package manager
PACKAGE_MANAGER=""
if command -v apt-get &> /dev/null; then
  PACKAGE_MANAGER="apt"
elif command -v dnf &> /dev/null; then
  PACKAGE_MANAGER="dnf"
else
  log "ERROR: Neither apt nor dnf found. Please install git and curl manually and re-run."
  exit 1
fi

# 1. Install Prerequisites (git and curl)
log "Installing prerequisites (git and curl)..."
if ! command -v git &> /dev/null || ! command -v curl &> /dev/null; then
  if [ "$PACKAGE_MANAGER" = "apt" ]; then
    sudo apt-get update
    sudo apt-get install -y git curl
  elif [ "$PACKAGE_MANAGER" = "dnf" ]; then
    sudo dnf install -y git curl
  fi
else
  echo "Git and curl are already installed."
fi

# 2. Create directory and clone Nix configuration repository
log "Cloning your Nix Flake repository..."
if [ -d "$FLAKE_REPO_ROOT/.git" ]; then
  echo "Repository already seems to be cloned in $FLAKE_REPO_ROOT. Pulling latest changes..."
  cd "$FLAKE_REPO_ROOT"
  git pull
else
  mkdir -p "$(dirname "$FLAKE_REPO_ROOT")" # Ensure parent directory exists
  git clone "$GITHUB_REPO_URL" "$FLAKE_REPO_ROOT"
  cd "$FLAKE_REPO_ROOT"
fi
echo "Successfully cloned/updated repository to $FLAKE_REPO_ROOT"

# 3. Install Nix
log "Installing Nix package manager..."
if command -v nix &> /dev/null; then
  echo "Nix seems to be already installed."
else
  # Multi-user Nix installation (will be interactive)
  # Consider --no-daemon for a non-interactive single-user install if preferred,
  # but multi-user is generally recommended.
  sh <(curl -L https://nixos.org/nix/install) --daemon
  echo "Nix installation script finished."
  echo "IMPORTANT: You might need to source the Nix environment or start a new shell."
  # Attempt to source it for the current script session
  if [ -f '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    # shellcheck source=/dev/null
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    echo "Sourced Nix daemon profile for current session."
  elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    echo "Sourced Nix single-user profile for current session."
  fi
  if ! command -v nix &> /dev/null; then
     log "ERROR: 'nix' command not found after attempting to source profile. Please open a new terminal and re-run the script, or ensure Nix is in your PATH."
     exit 1
  fi
fi

# 4. Enable Flakes in Nix configuration (if not already enabled)
log "Ensuring Nix Flakes are enabled..."
NIX_CONF_FILE="/etc/nix/nix.conf"
FLAKES_LINE="experimental-features = nix-command flakes"
if [ -f "$NIX_CONF_FILE" ]; then
  if grep -q "^experimental-features\s*=" "$NIX_CONF_FILE"; then
    if ! grep -q "nix-command" "$NIX_CONF_FILE" || ! grep -q "flakes" "$NIX_CONF_FILE"; then
      log "WARNING: 'experimental-features' line found but might not include 'nix-command flakes'. Manual check of $NIX_CONF_FILE recommended."
      # This part could be more robust, e.g., by appending if not present.
      # For now, we'll assume if the line exists, it's either correct or user-managed.
      echo "Assuming existing 'experimental-features' line is sufficient or user-managed."
    else
      echo "Flakes and nix-command already seem to be enabled in $NIX_CONF_FILE."
    fi
  else
    echo "$FLAKES_LINE" | sudo tee -a "$NIX_CONF_FILE" > /dev/null
    echo "Added '$FLAKES_LINE' to $NIX_CONF_FILE."
    NEEDS_DAEMON_RESTART=true
  fi
else
  # If nix.conf doesn't exist, Nix might be configured differently or this is an old setup.
  # The Nix installer should create it. If not, this is an issue.
  log "WARNING: $NIX_CONF_FILE not found. This might indicate an issue with Nix installation or a non-standard setup."
  # Attempt to create it if user is root-like for this part
  if sudo touch "$NIX_CONF_FILE" 2>/dev/null; then
      echo "$FLAKES_LINE" | sudo tee -a "$NIX_CONF_FILE" > /dev/null
      echo "Created $NIX_CONF_FILE and added '$FLAKES_LINE'."
      NEEDS_DAEMON_RESTART=true
  else
      log "ERROR: Could not create or write to $NIX_CONF_FILE. Please ensure Flakes are enabled manually."
  fi
fi

if [ "$NEEDS_DAEMON_RESTART" = true ] && command -v systemctl &> /dev/null; then
  log "Restarting nix-daemon service..."
  sudo systemctl restart nix-daemon.service
  echo "Nix daemon restarted."
elif [ "$NEEDS_DAEMON_RESTART" = true ]; then
  log "Nix daemon may need to be restarted manually for Flakes to be fully enabled."
fi

# 5. Apply Home Manager Configuration using the Flake
log "Applying Home Manager configuration from Flake..."
cd "$FLAKE_REPO_ROOT" # Ensure we are in the flake's directory

# Construct the Flake output name if not set directly
if [ -z "${FLAKE_OUTPUT_NAME_STATIC+x}" ]; then # Check if FLAKE_OUTPUT_NAME_STATIC is unset
  SYSTEM_ARCH=$(nix-shell -p nix-info --run "nix-info -m") # Get architecture like x86_64 or aarch64
  FLAKE_OUTPUT_NAME="${FLAKE_OUTPUT_USERNAME}-${SYSTEM_ARCH}-linux"
  echo "Constructed Flake output name: $FLAKE_OUTPUT_NAME"
else
  FLAKE_OUTPUT_NAME="$FLAKE_OUTPUT_NAME_STATIC"
  echo "Using static Flake output name: $FLAKE_OUTPUT_NAME"
fi


echo "Attempting to switch Home Manager configuration for output: $FLAKE_OUTPUT_NAME"
echo "This step might take a while, especially on the first run..."

# Use 'nix shell' to ensure home-manager command is available for the first switch
if nix shell nixpkgs#home-manager --command home-manager switch --flake .#"${FLAKE_OUTPUT_NAME}"; then
  log "Home Manager switch completed successfully!"
else
  log "ERROR: Home Manager switch failed. Please check the output for errors."
  log "Common issues:"
  log "1. The FLAKE_OUTPUT_NAME ('${FLAKE_OUTPUT_NAME}') might be incorrect. Verify it matches an output in your flake.nix."
  log "2. There might be errors in your Nix configuration itself."
  log "3. Nix daemon might not have restarted correctly if Flakes were just enabled."
  exit 1
fi

log "SETUP SCRIPT FINISHED!"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Log out of your current session and log back in for all changes to take full effect (especially your shell and environment variables)."
echo "2. If you included the LunarVim auto-installer, run 'lvim' once manually to complete its internal setup (plugin installation, etc.)."
echo "3. Verify your tools and configurations are working as expected."

exit 0

