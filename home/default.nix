# /my-nix-config/home/default.nix
{ pkgs, config, lib, inputs, system, ... }:

{
  # Set your username, home directory, and state version
  home.username = "james";
  home.homeDirectory = "/home/james";
  home.stateVersion = "23.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Basic packages
  home.packages = with pkgs; [
    cargo
    curl
    fd
    gcc
    git
    htop
    gnumake
    nodejs_20
    python3
    python3Packages.pynvim
    ripgrep
    tree
    unzip
  ];

  # Allow unfree packages if necessary
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
    # Add other unfree package names here if needed
  ];

  # Fonts configuration
  fonts.fontconfig.enable = true;

  # Shell aliases that apply to any shell
  home.shellAliases = {
    # Add your aliases here
  };

  # ZSH Configuration
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    
    # Init script to run before completion initialization
    initExtraBeforeCompInit = ''
      # Set preferred editor
      export EDITOR='nvim'
      export VISUAL='nvim'
    '';

    # Add any additional zsh configuration here
  };

  # Git Configuration (consolidated from git.nix)
  programs.git = {
    enable = true;
    userName = "James";  # Replace with your actual name
    userEmail = "jdevore4592@gmail.com";  # Replace with your actual email
    
    # Additional git configuration can go here
    extraConfig = {
      core = {
        editor = "nvim";
      };
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
    };
  };

  # Neovim Configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    # The plugins section might need to be updated if you're using
    # plugins that require additional configuration
    plugins = with pkgs.vimPlugins; [
      vim-nix
      # Consider adding these common plugins
      nvim-treesitter
      telescope-nvim
      lsp-zero-nvim
      # More plugins...
    ];
    
    # You might want to consider using extraLuaConfig instead of
    # extraConfig if you prefer Lua-based Neovim config
    extraConfig = ''
      " Your vim/neovim configuration here
      set number
      set relativenumber
      set expandtab
      set tabstop=2
      set shiftwidth=2
      
      " Add these for better quality of life
      set autoindent
      set smartindent
      set ignorecase
      set smartcase
      set mouse=a
      set clipboard+=unnamedplus
    '';
  };

  # You can add any other program configurations here
  # For example, VSCode:
  # programs.vscode = {
  #   enable = true;
  #   extensions = with pkgs.vscode-extensions; [
  #     # Add your preferred extensions
  #   ];
  # };

  programs.alacritty = {
    enable = true;
    settings = {
      font.size = 12.0;
      window.opacity = 0.95;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
