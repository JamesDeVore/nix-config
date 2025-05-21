# /my-nix-config/home/default.nix
{ pkgs, config, lib, inputs, system, ... }:

{
  # Set your username, home directory, and state version
  home.username = "james"; # Or a generic name like "dev"
  home.homeDirectory = "/home/james"; # Or "/home/dev"
  home.stateVersion = "23.11"; # Or your current NixOS/nixpkgs version

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Import your modularized configurations
  imports = [
    ./common.nix
    ./shells/zsh.nix
    ./editors/vscode.nix
    ./editors/nvim.nix
    ./tools/git.nix
    ./tools/node.nix
    ./tools/misc.nix
    # ./secrets/default.nix # For sops-nix or similar
  ];

  # Basic packages (many will be dependencies of configured programs)
  home.packages = with pkgs; [
    # direnv # Useful for project-specific environments on top of your global one
    htop   # System monitor
  ];

  # Allow unfree packages if necessary (e.g., for VSCode)
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
    # Add other unfree package names here if needed
  ];

  # Fonts (optional, but good for consistency)
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    # nerdfonts # Example: if your Zsh theme or editor setup needs it
    # FiraCode
    # JetBrainsMono
  ];
}
