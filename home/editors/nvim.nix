# /my-nix-config/home/editors/neovim.nix (or lunarvim.nix)
{ pkgs, config, lib, inputs, ... }:

let
  # Use a specific Neovim package.
  # For very recent Neovim, you might use neovim-nightly or an overlay.
  # Check LunarVim's current Neovim version requirements.
  # For example, if nixpkgs.neovim is recent enough:
  neovimPackage = pkgs.neovim;
  # Or, if you added the neovim-nightly-overlay to your flake.nix:
  # neovimPackage = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;

in
{
  # Install Neovim
  programs.neovim = {
    enable = true;
    package = neovimPackage;
    defaultEditor = true; # Optional: sets EDITOR=nvim
    vimAlias = true;      # Optional: aliases vim=nvim
  };

  # Install LunarVim's dependencies
  # Check LunarVim's documentation for the full, up-to-date list!
  home.packages = with pkgs; [
    # Core requirements
    git
    make
    unzip
    ripgrep # For searching
    fd      # For finding files

    # Python support for Neovim and plugins
    python3
    python3Packages.pynvim

    # Node.js support for Neovim Language Server Protocol (LSP) & formatters
    nodejs_20 # Or another recent version
    nodePackages.npm # Often needed for LSPs or tools installed via Mason/npm

    # Rust support (for tree-sitter, some LSPs, Telescope)
    cargo

    # Compilers (gcc or clang, often needed for building tree-sitter parsers or other native extensions)
    gcc # or clang

    # Optional but recommended for a better experience with LSPs / formatters
    # Check what LunarVim's Mason installs or what you plan to use:
    # Example Language Servers (LunarVim's Mason often handles these, but base tools can be useful)
    # lua-language-server
    # marksman # For markdown
    # nodePackages.typescript-language-server
    # nodePackages.vscode-json-languageserver
    # nixd # Nix Language Server (if you use it)

    # Formatters
    stylua # For Lua
    shfmt  # For shell scripts
    prettierd # For web dev files
  ];

  # Ensure ~/.local/bin is in PATH, as LunarVim installs 'lvim' there.
  # Home Manager usually does this by default if programs are installed there,
  # but it's good to be aware. You can explicitly add it if needed:
  # home.sessionPath = [ "$HOME/.local/bin" ];

  # Optional: If you want to manage your custom LunarVim config.lua with Nix
  xdg.configFile."lvim/config.lua" = {
    source = ./lvim-config/config.lua; # Create this file in your Nix config repo
    # text = '' -- Or define it inline
    --   -- Your LunarVim specific config overrides here
    --   -- For example:
    --   -- lvim.log.level = "warn"
    --   -- lvim.format_on_save.enabled = true
    --   -- table.insert(lvim.plugins, {
    --   --   "folke/tokyonight.nvim",
    --   --   lazy = false,
    --   --   priority = 1000,
    --   --   config = function()
    --   --     vim.cmd([[colorscheme tokyonight]])
    --   --   end,
    --   -- })
    -- '';
    recursive = false; # Ensure only this file is managed, not the whole lvim dir initially
  };
}
