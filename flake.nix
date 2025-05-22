# /my-nix-config/flake.nix
{
  description = "My Developer Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # Latest stable release
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs"; # Ensures home-manager uses the same nixpkgs
    };
    # For VSCode extensions if not all are in nixpkgs
    # nix-vscode-extensions = {
    #   url = "github:nix-community/nix-vscode-extensions";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # For Neovim plugins (example with nix-community/neovim-nightly-overlay)
    # neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Define supported systems (add others like aarch64-linux for Raspberry Pi)
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate home-manager configurations for each system
      mkHome = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs system; }; # Pass inputs to your home modules
          modules = [
            ./home/default.nix
            # You can add machine-specific modules here if needed:
            # (if builtins.pathExists ./home/${pkgs.lib.strings.escapeShellArg pkgs.hostName}.nix then ./home/${pkgs.lib.strings.escapeShellArg pkgs.hostName}.nix else {})
          ];
        };
    in
    {
      # Home Manager configurations for different systems
      # Access with: home-manager switch --flake .#yourusername@yourhostname
      # Or for a generic user 'dev':
      homeConfigurations = {
        "dev-x86_64-linux" = mkHome "x86_64-linux";
        "dev-aarch64-linux" = mkHome "aarch64-linux";
      };

      # A development shell you can enter with `nix develop`
      # Useful for managing this configuration itself or general tasks
      devShells.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        name = "my-dev-env-management";
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          git
          nix # For managing nix itself
          home-manager # For applying configurations
        ];
      };
    };
}
