# /my-nix-config/home/shells/zsh.nix
{ pkgs, config, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    # syntaxHighlighting.enable = true; # Or manage with a plugin manager

    # Oh My Zsh example (can be complex to manage purely declaratively)
    # A more Nix-native approach is often preferred using plugins below.
    # ohMyZsh = {
    #   enable = true;
    #   theme = "agnoster"; # Or your preferred theme
    #   plugins = [ "git" "sudo" ];
    # };

    # More granular plugin management (example using zsh-completions, zsh-syntax-highlighting)
    plugins = [
      { name = "zsh-autosuggestions"; src = pkgs.zsh-autosuggestions; }
      { name = "zsh-syntax-highlighting"; src = pkgs.zsh-syntax-highlighting; }
      { name = "zsh-completions"; src = pkgs.zsh-completions; }
      # Add other plugins by fetching their source if not in nixpkgs
      # {
      #   name = "my-custom-plugin";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "owner";
      #     repo = "repo";
      #     rev = "commit-hash-or-tag";
      #     sha256 = "sha256-hash"; # Get this with nix-prefetch-git or by building once with a fake hash
      #   };
      #   file = "my-custom-plugin.plugin.zsh"; # If the plugin file has a specific name
      # }
    ];

    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake /path/to/your/nixos-config#hostname"; # If on NixOS
      hm-switch = "home-manager switch --flake /path/to/your/my-nix-config#yourusername@yourhostname";
    };

    # You can source custom Zsh files
    # initExtra = ''
    #   source ${./my_custom_zsh_stuff.zsh}
    # '';

    # Or directly write Zsh configuration
    initExtraBeforeCompInit = ''
      # Example: Set preferred editor
      export EDITOR='nvim'
      export VISUAL='nvim'
    '';
  };

  # Ensure Zsh is the default shell (only takes effect on new logins or by running `chsh`)
  programs.bash.enable = false; # If you want to ensure Zsh is primary
  users.defaultUserShell = pkgs.zsh;
}
