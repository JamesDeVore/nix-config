# /my-nix-config/home/default.nix
{ pkgs, config, lib, inputs, system, pkgsWithNightlyNvim, ... }:

{
  # Set your username, home directory, and state version
  home.username = "james";
  home.homeDirectory = "/home/james";
  home.stateVersion = "23.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Basic packages from stable `pkgs`
  home.packages = with pkgs; [
    # Development tools
    cargo
    curl
    fd
    fzf
    gcc
    git
    gnumake
    htop
    lazygit
    lua
    luajitPackages.luarocks
    nil  # Nix language server
    nodejs_20
    
    # LunarVim Dependencies
    # Neovim itself is handled by programs.neovim.package
    nodePackages.neovim  # NodeJS provider for Neovim
    tree-sitter          # General tree-sitter CLI from stable for other uses
    python3
    python3Packages.pynvim  # Python provider for Neovim
    
    # Additional recommended dependencies for LunarVim
    fd
    ripgrep
    
    # Language servers (from stable `pkgs`)
    lua-language-server
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    
    # Utilities
    tree
    unzip
    wl-clipboard
    xclip
  ];

  # Allow unfree packages if necessary
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
  ];

  # Fonts configuration
  fonts.fontconfig.enable = true;

  # Shell aliases that apply to any shell
  home.shellAliases = {
    lv = "lvim";
    vi = "lvim";

    # --- Aliases for Managing Your Home Manager Config ---
    
    # Edit your main Home Manager configuration file
    # Assumes your flake is in '~/local-nix-home' as per your install.sh
    # and your main config is 'home/default.nix' within that.
    # Uses your $EDITOR.
    edithm = "$EDITOR ~/local-nix-home/home/default.nix";

    # Apply your Home Manager configuration
    # Assumes flake in '~/local-nix-home' and output 'dev-x86_64-linux'
    # (Adjust 'dev-x86_64-linux' if your username/arch or flake output name is different)
    applyhm = "home-manager switch --flake ~/local-nix-home#dev-x86_64-linux";

    # Update all flake inputs (like nixpkgs) and then apply the configuration
    updatehm = "cd ~/local-nix-home && nix flake update && home-manager switch --flake .#dev-x86_64-linux && cd -";
    
    # Quickly rebuild and switch to the current configuration (useful after edits)
    # This is the same as applyhm if you are already in the flake directory.
    # If you're often in the flake dir, you might prefer a shorter alias like 'hms'.
    # hms = "home-manager switch --flake .#dev-x86_64-linux"; 
  };

  # ZSH Configuration
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    
    # You can also define Zsh-specific aliases here if you prefer,
    # though home.shellAliases is more general.
    # shellAliases = {
    #   g = "git";
    # };

    initExtra = ''
      # --- PATH MODIFICATIONS ---
      # Example: Ensure $HOME/.local/bin is in PATH
      if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
      fi
      # Example: Add another custom directory to PATH
      # MY_CUSTOM_SCRIPTS_DIR="$HOME/my-scripts"
      # if [[ -d "$MY_CUSTOM_SCRIPTS_DIR" && ":$PATH:" != *":$MY_CUSTOM_SCRIPTS_DIR:"* ]]; then
      #  export PATH="$MY_CUSTOM_SCRIPTS_DIR:$PATH"
      # fi

      # --- OTHER ZSH CUSTOMIZATIONS ---
      # You can put other Zsh specific settings here
      # For example, setting options:
      # setopt auto_cd
      # export SOME_VARIABLE="some_value"
    '';
    
    initExtraBeforeCompInit = ''
      # Set preferred editor
      export EDITOR='nvim' # This will use the nvim from programs.neovim.package
      export VISUAL='nvim'
    '';

    # --- ZSH PLUGIN MANAGEMENT (Declarative) ---
    # Home Manager can manage many common Zsh plugins.
    # You're already using boolean flags for autosuggestions and syntax-highlighting.
    # For other plugins, you'd typically use the 'plugins' attribute.
    # plugins = [
    #   {
    #     name = "zsh-nvm"; # Example: for Node Version Manager
    #     src = pkgs.fetchFromGitHub {
    #       owner = "lukechilds";
    #       repo = "zsh-nvm";
    #       rev = "v0.10.0"; # Check for the latest tag/commit
    #       sha256 = "0q38...replace_with_actual_hash..."; # Get with nix-prefetch-git or build failure
    #     };
    #   }
    #   # Another example: using a plugin directly from nixpkgs if available
    #   { name = "fzf-tab"; src = pkgs.zsh-fzf-tab; }
    # ];
    # Some plugins might require specific configuration in initExtra.
  };

  # Git Configuration
  programs.git = {
    enable = true;
    userEmail = "jdevore4592@gmail.com";
    userName = "James";
    extraConfig = {
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull.rebase = true;
      # Prefer SSH for GitHub URLs
      "url.git@github.com:.insteadOf" = "https://github.com/";
    };
  };

  # Neovim Configuration using neovim-nightly
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # Use neovim-nightly from the pkgs set that has the overlay applied
    # The overlay might provide it simply as 'neovim' or 'neovim-nightly'.
    # Let's try pkgsWithNightlyNvim.neovim
    package = pkgsWithNightlyNvim.neovim;
    
    # Since LunarVim manages its plugins, this can be minimal or empty
    plugins = [ ]; # Example: pkgs.vimPlugins.vim-nix if needed outside LunarVim
    
    # LunarVim will manage most of this. Keep minimal if any.
    extraConfig = ''
      set number
      set relativenumber
    '';

    extraPackages = with pkgs; [ # Runtime dependencies for Neovim/plugins
      tree-sitter # For access to tree-sitter CLI if plugins need it
      ripgrep
      fd
    ];
  };

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

  # Install LunarVim using home-manager's activation script
  home.activation = {
    installLunarVim = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Ensure this directory exists for the PATH modification below
      mkdir -p "$HOME/.local/bin"

      if [ ! -d "$HOME/.local/share/lunarvim" ]; then
        echo "Installing LunarVim..."
        
        # Create a temporary PATH with all necessary tools
        # Reference the actual neovim package that will be installed by programs.neovim
        NIX_TOOLS_PATH="${lib.makeBinPath ([config.programs.neovim.package] ++ (with pkgs; [ # Stable pkgs for other tools
          bash
          coreutils
          curl
          findutils
          git
          gnugrep
          gnumake
          gnused
          nodejs_20
          python3
        ]))}"
        # Add $HOME/.local/bin to the PATH for the installer itself
        export PATH="$NIX_TOOLS_PATH:$HOME/.local/bin:$PATH"
        
        TEMP_DIR=$(mktemp -d)
        cd $TEMP_DIR
        
        curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/master/utils/installer/install.sh -o install.sh
        sed -i 's/check_system_deps$/#check_system_deps/g' install.sh
        bash install.sh --no-install-dependencies
        
        cd $HOME
        rm -rf $TEMP_DIR
      else
        echo "LunarVim already installed, skipping installation"
      fi
    '';
  };
  
  # Create a basic LunarVim config
  home.file.".config/lvim/config.lua".text = ''
    -- General
    lvim.log.level = "warn"
    lvim.format_on_save.enabled = true
    lvim.colorscheme = "lunar" -- or your preferred theme like 'tokyonight'
    
    lvim.leader = "space"
    
    -- If you want to manage LSPs, formatters, linters via Nix and prevent LunarVim from auto-installing them:
    -- lvim.lsp.automatic_servers_installation = false

    lvim.plugins = {
      {"folke/trouble.nvim"},
      {"github/copilot.vim"}, -- If you use Copilot
      {"nvim-treesitter/nvim-treesitter-context"},
    }
    
    -- Example: if you manage rust-analyzer via Nix, skip LV's auto-config for it
    -- vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "rust_analyzer" })
    
    local formatters = require "lvim.lsp.null-ls.formatters"
    formatters.setup {
      { command = "prettier", filetypes = { "typescript", "typescriptreact", "javascript", "html", "css", "yaml", "markdown", "json" } },
      { command = "nixfmt", filetypes = { "nix" } },
    }
    
    local linters = require "lvim.lsp.null-ls.linters"
    linters.setup {
      { command = "eslint", filetypes = { "typescript", "typescriptreact", "javascript" } },
    }
    
    vim.opt.relativenumber = true
    vim.opt.wrap = false
    vim.opt.scrolloff = 8
    vim.opt.sidescrolloff = 8
  '';
}
