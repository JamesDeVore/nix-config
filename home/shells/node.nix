# /my-nix-config/home/tools/node.nix
{ pkgs, ... }:

{
  # Install a specific version of Node.js
  home.packages = with pkgs; [
    nodejs_20 # Or nodejs_18, etc. Check nixpkgs for available versions
    # yarn # If you use Yarn
    # pnpm # If you use pnpm
  ];

  # You can also manage global npm packages, though it's often better to manage
  # these per-project using package.json and a nix-shell or direnv.
  # programs.npm.packages = [ "cowsay" ];
}
