#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Warn if not running under bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script must be run with bash."
  echo "Please run it as: ./install.sh"
  exit 1
fi

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

# Set up an isolated Nix home directory
ORIGINAL_HOME="$HOME"
LOCAL_NIX_HOME="$ORIGINAL_HOME/local-nix-home"

# This variable will be used as the root for the flake configuration.
FLAKE_REPO_ROOT="$LOCAL_NIX_HOME"
echo "Nix Flake configuration will be cloned/updated in: $FLAKE_REPO_ROOT"

# Ensure the target directory for the flake repository exists
if [ ! -d "$FLAKE_REPO_ROOT" ]; then
  echo "Creating Nix Flake configuration directory at $FLAKE_REPO_ROOT"
  mkdir -p "$FLAKE_REPO_ROOT"
fi

# Don't change HOME environment variable
# export HOME="$LOCAL_NIX_HOME"  # Remove or comment this line
echo "Using $FLAKE_REPO_ROOT as the flake directory for this script."

# --- USER CONFIGURATION: PLEASE EDIT THESE VARIABLES ---
# Your GitHub repository URL for your Nix Flake configuration
# Example: GITHUB_REPO_URL="https://github.com/yourusername/my-nix-dots.git"
GITHUB_REPO_URL="https://github.com/JamesDevore/nix-config"

# The local directory where your Nix configuration will be cloned.
# This script will create this directory if it doesn't exist.
# Example: FLAKE_REPO_ROOT="$HOME/my-nix-setup"
# FLAKE_REPO_ROOT="$HOME/nix-config" # Changed from ~/nix to avoid potential conflicts if ~/nix is special

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

# Function to fix Nix cache permissions
fix_nix_permissions() {
  log "Fixing Nix-related permissions..."
  
  # List of directories to check and fix
  local dirs=(
    "$HOME/.nix-profile"
    "$HOME/.nix-defexpr"
    "$HOME/.cache/nix"
    "$HOME/.local/state/nix"
    "$HOME/.local/share/nix"
  )
  
  # Create directories if they don't exist and fix permissions
  for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      echo "Creating directory: $dir"
      mkdir -p "$dir"
    fi
    echo "Fixing permissions for: $dir"
    sudo chown -R "$(id -u):$(id -g)" "$dir"
    sudo chmod -R 755 "$dir"
  done

  # Special handling for nix-daemon directories if they exist
  if [ -d "/nix" ]; then
    echo "Fixing /nix directory permissions..."
    sudo chown -R "$(id -u):$(id -g)" "/nix/var/nix/profiles/per-user/$USER"
  fi

  # Ensure the Nix store has correct permissions
  if [ -d "/nix/store" ]; then
    echo "Ensuring correct Nix store permissions..."
    sudo chown -R root:nixbld /nix/store
    sudo chmod -R 1775 /nix/store
  fi

  echo "Nix permissions fixed."
}

# --- Function to setup SSH keys ---
setup_ssh_keys() {
  log "Setting up SSH keys for Git integration..."
  local ssh_dir="$ORIGINAL_HOME/.ssh"
  local id_ed25519_pub="$ssh_dir/id_ed25519.pub"
  local id_ed25519_priv="$ssh_dir/id_ed25519"
  local id_rsa_pub="$ssh_dir/id_rsa.pub" # Check for older RSA keys as well
  local id_rsa_priv="$ssh_dir/id_rsa"

  echo "Checking for existing SSH keys in $ssh_dir..."

  if [ -f "$id_ed25519_priv" ] || [ -f "$id_rsa_priv" ]; then
    echo "Existing SSH key(s) found."
    if [ -f "$id_ed25519_pub" ]; then
      echo "--------------------------------------------------"
      echo "Your ED25519 Public Key ($id_ed25519_pub):"
      cat "$id_ed25519_pub"
      echo "--------------------------------------------------"
    fi
    if [ -f "$id_rsa_pub" ]; then
      echo "--------------------------------------------------"
      echo "Your RSA Public Key ($id_rsa_pub):"
      cat "$id_rsa_pub"
      echo "--------------------------------------------------"
    fi
    echo "Please ensure one of these public keys is added to your GitHub, GitLab, or other Git provider."
    echo "You can typically add SSH keys at: https://github.com/settings/keys"
    echo "If you need to use a specific key, ensure your SSH agent is configured or use an SSH config file."

    return
  fi

  echo "No existing SSH key (id_ed25519 or id_rsa) found in $ssh_dir."
  read -r -p "Do you want to generate a new ED25519 SSH key now? (y/N): " generate_key_prompt
  if [[ ! "$generate_key_prompt" =~ ^[Yy]$ ]]; then
    echo "Skipping SSH key generation. Please ensure your SSH keys are configured manually for Git integration."

    return
  fi

  local email
  # Try to get email from global git config if available, otherwise prompt
  # This assumes git command is available (installed in prerequisites)
  if command -v git &> /dev/null && git config --global user.email &> /dev/null; then
    email=$(git config --global user.email)
    echo "Using email from global git config for SSH key: $email"
  else
    read -r -p "Please enter your email address for the SSH key comment: " email
  fi

  if [ -z "$email" ]; then
    echo "Email address is required for the SSH key comment. Aborting SSH key generation."

    return
  fi

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  
  echo "Generating ED25519 SSH key. You will be prompted for a file and passphrase."
  echo "It's recommended to save it to the default location ($id_ed25519_priv)."
  echo "Using a strong passphrase is highly recommended."
  ssh-keygen -t ed25519 -C "$email" -f "$id_ed25519_priv" # User will be prompted for passphrase

  if [ -f "$id_ed25519_pub" ]; then
    echo "--------------------------------------------------"
    echo "New ED25519 SSH key generated successfully!"
    echo "Your new Public Key ($id_ed25519_pub) is:"
    cat "$id_ed25519_pub"
    echo "--------------------------------------------------"
    echo ""
    echo "IMPORTANT INSTRUCTIONS:"
    echo "1. Copy the entire public key text block above (starting with 'ssh-ed25519...' and ending with your email)."
    echo "2. Add this public key to your GitHub account: https://github.com/settings/keys"
    echo "   (Or to your respective Git provider like GitLab, Bitbucket, etc.)"
    echo "3. After adding the key, you can test the connection by running:"
    echo "     ssh -T git@github.com"
    echo "   (Replace 'github.com' if you use a different provider)."
    read -r -p "Press Enter to continue after you have added the key to your Git provider..."
  else
    echo "ERROR: SSH key generation seems to have failed. Public key file not found at $id_ed25519_pub."
    echo "Please try generating it manually or check for errors."
  fi
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
  log "ERROR: Neither apt nor dnf found. Please install git, curl, and jq manually and re-run."
  exit 1
fi

# 1. Install Prerequisites (git, curl, and jq)
log "Installing prerequisites (git, curl, and jq)..."
if ! command -v git &> /dev/null || ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
  echo "Attempting to install missing prerequisites..."
  if [ "$PACKAGE_MANAGER" = "apt" ]; then
    sudo apt-get update
    sudo apt-get install -y git curl jq
  elif [ "$PACKAGE_MANAGER" = "dnf" ]; then
    sudo dnf install -y git curl jq
  fi
  # Verify installation
  if ! command -v git &> /dev/null || ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    log "ERROR: Failed to install all prerequisites (git, curl, jq). Please install them manually and re-run."
    exit 1
  fi
else
  echo "Git, curl, and jq are already installed."
fi

# Call SSH key setup after prerequisites are installed
setup_ssh_keys

# 2. Create directory and clone Nix configuration repository
log "Cloning/Updating your Nix Flake repository..."
if [ -d "$FLAKE_REPO_ROOT/.git" ]; then
  # Ensure correct ownership
  sudo chown -R "$(id -u):$(id -g)" "$FLAKE_REPO_ROOT"
  # Mark as safe for git
  git config --global --add safe.directory "$FLAKE_REPO_ROOT"
  echo "Repository already seems to be cloned in $FLAKE_REPO_ROOT. Pulling latest changes..."
  cd "$FLAKE_REPO_ROOT"
  git pull
else
  # Ensure parent directory exists (though mkdir -p $FLAKE_REPO_ROOT earlier should handle it)
  mkdir -p "$(dirname "$FLAKE_REPO_ROOT")" 
  echo "Cloning $GITHUB_REPO_URL into $FLAKE_REPO_ROOT..."
  git clone "$GITHUB_REPO_URL" "$FLAKE_REPO_ROOT"
  # Ensure correct ownership
  sudo chown -R "$(id -u):$(id -g)" "$FLAKE_REPO_ROOT"
  # Mark as safe for git
  git config --global --add safe.directory "$FLAKE_REPO_ROOT"
  cd "$FLAKE_REPO_ROOT"
fi

# 3. Install Nix
log "Installing Nix package manager..."
if command -v nix &> /dev/null; then
  echo "Nix seems to be already installed."
  # Fix permissions even if Nix is already installed
  fix_nix_permissions
else
  # Multi-user Nix installation (will be interactive)
  yes | sh <(curl -L https://nixos.org/nix/install) --daemon
  echo "Nix installation script finished."
  echo "IMPORTANT: You might need to source the Nix environment or start a new shell."
  
  # Fix permissions after fresh install
  fix_nix_permissions
  
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

# Ensure the user owns their Nix cache directory
# This can prevent permission errors during flake updates if sudo was used inappropriately before.
if [ -d "$ORIGINAL_HOME/.cache/nix" ]; then
  log "Ensuring current user owns $ORIGINAL_HOME/.cache/nix..."
  sudo chown -R "$(id -u):$(id -g)" "$ORIGINAL_HOME/.cache/nix" || echo "Warning: Failed to chown $ORIGINAL_HOME/.cache/nix. This might cause issues if the directory is not writable."
else
  echo "$ORIGINAL_HOME/.cache/nix does not exist, skipping chown. Nix will create it."
fi

# 5. Apply Home Manager Configuration using the Flake
log "Applying Home Manager configuration from Flake..."
cd "$FLAKE_REPO_ROOT" # Ensure we are in the flake's directory

# Check if flake.lock exists and is valid JSON
if [ -f "flake.lock" ]; then
  if [ ! -s "flake.lock" ] || ! jq empty flake.lock >/dev/null 2>&1; then
    echo "flake.lock is empty or not valid JSON. Deleting and regenerating..."
    rm -f flake.lock # Use rm -f to avoid error if it was a broken symlink etc.
    nix flake update --log-format internal-json -v # Added verbosity and better log format for potential debug
  else
    echo "flake.lock found and appears to be valid JSON."
    # Optionally, you might still want to run 'nix flake update' here if you always want the latest.
    # For now, we only update if it was broken or missing.
  fi
else
  echo "flake.lock not found. Generating a new one..."
  nix flake update --log-format internal-json -v # Added verbosity
fi

# Construct the Flake output name if not set directly
if [ -z "${FLAKE_OUTPUT_NAME_STATIC+x}" ]; then # Check if FLAKE_OUTPUT_NAME_STATIC is unset
  SYSTEM_ARCH=$(uname -m)
  case "$SYSTEM_ARCH" in
    x86_64) SYSTEM_ARCH="x86_64" ;;
    aarch64) SYSTEM_ARCH="aarch64" ;;
    *) echo "Unknown architecture: $SYSTEM_ARCH"; exit 1 ;;
  esac

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

