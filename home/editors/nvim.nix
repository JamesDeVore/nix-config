# /my-nix-config/home/editors/neovim.nix (or lunarvim.nix)
{ pkgs, lib, config, ... }: # Make sure lib and config are available

let
  # ... (your neovimPackage and dependency definitions from before)
  neovimPackage = pkgs.neovim; # Or your chosen Neovim package
in
{
  # Install Neovim (as before)
  programs.neovim = {
    enable = true;
    package = neovimPackage;
    defaultEditor = true;
    vimAlias = true;
  };

  # Install LunarVim's dependencies (as before)
  home.packages = with pkgs; [
    git
    make
    unzip
    ripgrep
    fd
    python3
    python3Packages.pynvim
    nodejs_20 # Or your chosen Node.js version
    nodePackages.npm
    cargo
    gcc
    # Ensure curl is also listed here if not already pulled in by something else,
    # as the activation script will use it.
    curl
  ];

  # Optional: Manage your custom LunarVim config.lua (as before)
  xdg.configFile."lvim/config.lua" = {
    source = ./lvim-config/config.lua; # Or use `text` attribute
    # ...
  };

  # Activation script to install LunarVim if not already present
  home.activation.installLunarVim = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Define paths for checking LunarVim's presence
    # Note: $HOME is automatically set by Home Manager in this context
    LVIM_EXECUTABLE="$HOME/.local/bin/lvim"
    LVIM_CONFIG_DIR="$HOME/.config/lvim"
    LVIM_SHARE_DIR="$HOME/.local/share/lunarvim"

    # Check if lvim executable or its primary share directory exists
    if [ ! -f "$LVIM_EXECUTABLE" ] && [ ! -d "$LVIM_SHARE_DIR" ]; then
      echo "LunarVim not found at $LVIM_EXECUTABLE or $LVIM_SHARE_DIR. Attempting installation..."

      # Ensure ~/.local/bin exists, as the installer expects it
      mkdir -p "$HOME/.local/bin"

      # Command to install LunarVim (non-interactively)
      # Using the --yes flag for non-interactive installation
      # Ensure pkgs.bash and pkgs.curl are available.
      # They are usually on PATH if included in home.packages.
      # Using explicit paths for robustness:
      echo "Running LunarVim installer script..."
      ${pkgs.bash}/bin/bash <(${pkgs.curl}/bin/curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/rolling/utils/installer/install.sh) --yes

      # Check if the lvim executable was created after installation
      if [ -f "$LVIM_EXECUTABLE" ]; then
        echo "LunarVim installation script finished. lvim executable found at $LVIM_EXECUTABLE."
        echo "You might need to run 'lvim' once manually to complete setup (e.g., plugin installation)."
      else
        echo "LunarVim installation script finished, but $LVIM_EXECUTABLE was not found. Please check for errors."
      fi
    else
      echo "LunarVim already detected at $LVIM_EXECUTABLE or $LVIM_SHARE_DIR. Skipping installation."
    fi
  '';
}

