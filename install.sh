#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if script is run as root
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: This script should not be run as root. It will use 'sudo' where necessary."
  exit 1
fi

# Detect package manager and install prerequisites
if command -v apt-get &> /dev/null; then
  sudo apt-get update
  sudo apt-get install -y git curl
elif command -v dnf &> /dev/null; then
  sudo dnf install -y git curl
else
  echo "ERROR: Neither apt nor dnf found. Please install git and curl manually and re-run."
  exit 1
fi

# Clone Nix configuration repository
REPO_URL="https://github.com/JamesDevore/nix-config"
TARGET_DIR="$HOME/nix-config"

if [ -d "$TARGET_DIR/.git" ]; then
  echo "Repository already exists. Pulling latest changes..."
  cd "$TARGET_DIR"
  git pull
else
  echo "Cloning repository..."
  git clone "$REPO_URL" "$TARGET_DIR"
  cd "$TARGET_DIR"
fi

# Install Nix if not already installed
if ! command -v nix &> /dev/null; then
  echo "Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --daemon

  # Source Nix environment
  if [ -f '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  fi
fi

# Enable Flakes
NIX_CONF="/etc/nix/nix.conf"
if [ ! -f "$NIX_CONF" ] || ! grep -q "experimental-features.*flakes" "$NIX_CONF"; then
  echo "Enabling Nix Flakes..."
  echo "experimental-features = nix-command flakes" | sudo tee -a "$NIX_CONF"
  if command -v systemctl &> /dev/null; then
    sudo systemctl restart nix-daemon.service
  fi
fi

# Apply Home Manager configuration
echo "Applying Home Manager configuration..."
nix shell nixpkgs#home-manager --command home-manager switch --flake .#dev-x86_64-linux

echo "Setup complete! Please log out and back in for all changes to take effect."

